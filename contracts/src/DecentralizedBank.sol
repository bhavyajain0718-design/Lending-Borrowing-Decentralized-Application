// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

contract DecentralizedBank {
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8500;

    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    IERC20 public immutable rewardToken;

    uint256 public collateralPriceInUsd = 2000e18; // 1 collateral token = $2000
    uint256 public borrowTokenPriceInUsd = 1e18; // stable token
    uint256 public maxLtvBps = 7500;
    uint256 public liquidationBonusBps = 500;

    uint256 public totalStaked;
    uint256 public rewardPerSecond = 0.01e18;
    uint256 public lastRewardTime;
    uint256 public accRewardPerShare;

    struct Position {
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 unclaimedRewards;
    }

    mapping(address => Position) public positions;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 debtRepaid, uint256 collateralSeized);

    constructor(address _collateral, address _borrow, address _reward) {
        collateralToken = IERC20(_collateral);
        borrowToken = IERC20(_borrow);
        rewardToken = IERC20(_reward);
        lastRewardTime = block.timestamp;
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "INVALID_AMOUNT");
        _accrueRewards(msg.sender);
        positions[msg.sender].collateralAmount += amount;
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "INVALID_AMOUNT");
        _accrueRewards(msg.sender);
        Position storage p = positions[msg.sender];
        require(p.collateralAmount >= amount, "INSUFFICIENT_COLLATERAL");

        p.collateralAmount -= amount;
        require(_isHealthy(msg.sender), "UNHEALTHY_POSITION");

        require(collateralToken.transfer(msg.sender, amount), "TRANSFER_FAILED");
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "INVALID_AMOUNT");
        _accrueRewards(msg.sender);

        Position storage p = positions[msg.sender];
        p.debtAmount += amount;

        require(_withinMaxLtv(msg.sender), "EXCEEDS_MAX_LTV");
        require(borrowToken.transfer(msg.sender, amount), "TRANSFER_FAILED");
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "INVALID_AMOUNT");
        _accrueRewards(msg.sender);

        Position storage p = positions[msg.sender];
        uint256 toRepay = amount > p.debtAmount ? p.debtAmount : amount;
        require(toRepay > 0, "NO_DEBT");

        p.debtAmount -= toRepay;
        require(borrowToken.transferFrom(msg.sender, address(this), toRepay), "TRANSFER_FAILED");
        emit Repaid(msg.sender, toRepay);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "INVALID_AMOUNT");
        _accrueRewards(msg.sender);

        Position storage p = positions[msg.sender];
        p.stakedAmount += amount;
        totalStaked += amount;

        require(collateralToken.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        p.rewardDebt = (p.stakedAmount * accRewardPerShare) / PRECISION;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "INVALID_AMOUNT");
        _accrueRewards(msg.sender);

        Position storage p = positions[msg.sender];
        require(p.stakedAmount >= amount, "INSUFFICIENT_STAKE");
        p.stakedAmount -= amount;
        totalStaked -= amount;

        p.rewardDebt = (p.stakedAmount * accRewardPerShare) / PRECISION;
        require(collateralToken.transfer(msg.sender, amount), "TRANSFER_FAILED");
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external {
        _accrueRewards(msg.sender);
        Position storage p = positions[msg.sender];
        uint256 reward = p.unclaimedRewards;
        require(reward > 0, "NO_REWARDS");
        p.unclaimedRewards = 0;
        require(rewardToken.transfer(msg.sender, reward), "TRANSFER_FAILED");
        emit RewardsClaimed(msg.sender, reward);
    }

    function liquidate(address user, uint256 debtToRepay) external {
        require(debtToRepay > 0, "INVALID_AMOUNT");
        require(!_isHealthy(user), "POSITION_HEALTHY");

        Position storage p = positions[user];
        uint256 repayAmount = debtToRepay > p.debtAmount ? p.debtAmount : debtToRepay;

        uint256 collateralEquivalent = _usdToCollateral((repayAmount * borrowTokenPriceInUsd) / PRECISION);
        uint256 bonus = (collateralEquivalent * liquidationBonusBps) / 10_000;
        uint256 collateralToSeize = collateralEquivalent + bonus;
        if (collateralToSeize > p.collateralAmount) {
            collateralToSeize = p.collateralAmount;
        }

        p.debtAmount -= repayAmount;
        p.collateralAmount -= collateralToSeize;

        require(borrowToken.transferFrom(msg.sender, address(this), repayAmount), "TRANSFER_FAILED");
        require(collateralToken.transfer(msg.sender, collateralToSeize), "TRANSFER_FAILED");
        emit Liquidated(user, msg.sender, repayAmount, collateralToSeize);
    }

    function getHealthFactor(address user) public view returns (uint256) {
        Position storage p = positions[user];
        if (p.debtAmount == 0) return type(uint256).max;

        uint256 collateralUsd = (p.collateralAmount * collateralPriceInUsd) / PRECISION;
        uint256 adjustedCollateral = (collateralUsd * LIQUIDATION_THRESHOLD_BPS) / 10_000;
        uint256 debtUsd = (p.debtAmount * borrowTokenPriceInUsd) / PRECISION;
        return (adjustedCollateral * PRECISION) / debtUsd;
    }

    function getPosition(address user)
        external
        view
        returns (uint256 collateralAmount, uint256 debtAmount, uint256 stakedAmount, uint256 pendingRewards)
    {
        Position storage p = positions[user];
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 duration = block.timestamp - lastRewardTime;
            _accRewardPerShare += (duration * rewardPerSecond * PRECISION) / totalStaked;
        }

        uint256 accumulated = (p.stakedAmount * _accRewardPerShare) / PRECISION;
        uint256 pending = accumulated > p.rewardDebt ? accumulated - p.rewardDebt : 0;

        return (p.collateralAmount, p.debtAmount, p.stakedAmount, p.unclaimedRewards + pending);
    }

    function setPriceConfig(uint256 _collateralPriceInUsd, uint256 _borrowTokenPriceInUsd) external {
        collateralPriceInUsd = _collateralPriceInUsd;
        borrowTokenPriceInUsd = _borrowTokenPriceInUsd;
    }

    function setRiskConfig(uint256 _maxLtvBps, uint256 _liquidationBonusBps) external {
        require(_maxLtvBps <= 9000, "LTV_TOO_HIGH");
        require(_liquidationBonusBps <= 2000, "BONUS_TOO_HIGH");
        maxLtvBps = _maxLtvBps;
        liquidationBonusBps = _liquidationBonusBps;
    }

    function setRewardRate(uint256 _rewardPerSecond) external {
        _updateGlobalRewards();
        rewardPerSecond = _rewardPerSecond;
    }

    function _withinMaxLtv(address user) internal view returns (bool) {
        Position storage p = positions[user];
        if (p.debtAmount == 0) return true;

        uint256 collateralUsd = (p.collateralAmount * collateralPriceInUsd) / PRECISION;
        uint256 maxDebtUsd = (collateralUsd * maxLtvBps) / 10_000;
        uint256 debtUsd = (p.debtAmount * borrowTokenPriceInUsd) / PRECISION;

        return debtUsd <= maxDebtUsd;
    }

    function _isHealthy(address user) internal view returns (bool) {
        return getHealthFactor(user) >= PRECISION;
    }

    function _usdToCollateral(uint256 usdAmount) internal view returns (uint256) {
        return (usdAmount * PRECISION) / collateralPriceInUsd;
    }

    function _updateGlobalRewards() internal {
        if (block.timestamp <= lastRewardTime) return;
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 duration = block.timestamp - lastRewardTime;
        uint256 rewardAmount = duration * rewardPerSecond;
        accRewardPerShare += (rewardAmount * PRECISION) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    function _accrueRewards(address user) internal {
        _updateGlobalRewards();
        Position storage p = positions[user];

        uint256 accumulated = (p.stakedAmount * accRewardPerShare) / PRECISION;
        uint256 pending = accumulated > p.rewardDebt ? accumulated - p.rewardDebt : 0;
        if (pending > 0) {
            p.unclaimedRewards += pending;
        }

        p.rewardDebt = accumulated;
    }
}
