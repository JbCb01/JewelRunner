import type { ReactNode } from "react";

export function Loading() {
  return <p role="status">Ładowanie…</p>;
}

export function ErrorBox({ message, onRetry, children }: { message: string; onRetry?: () => void; children?: ReactNode }) {
  return (
    <div className="notice error" role="alert">
      <p>{message}</p>
      {onRetry && (
        <button className="button" onClick={onRetry}>
          Spróbuj ponownie
        </button>
      )}
      {children}
    </div>
  );
}

export function ProgressBar({ value }: { value: number }) {
  return (
    <div className="progress" role="progressbar" aria-valuenow={value} aria-valuemin={0} aria-valuemax={100}>
      <span style={{ width: `${value}%` }} />
    </div>
  );
}
