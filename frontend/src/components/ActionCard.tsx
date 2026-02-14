import { FormEvent, useState } from "react";

type Props = {
  title: string;
  cta: string;
  onSubmit: (amount: string) => Promise<void>;
};

export default function ActionCard({ title, cta, onSubmit }: Props) {
  const [amount, setAmount] = useState("");
  const [loading, setLoading] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!amount) return;
    setLoading(true);
    try {
      await onSubmit(amount);
      setAmount("");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form className="card" onSubmit={submit}>
      <h3>{title}</h3>
      <input value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="0.0" type="number" step="0.01" min="0" required />
      <button disabled={loading} type="submit">
        {loading ? "Processing..." : cta}
      </button>
    </form>
  );
}
