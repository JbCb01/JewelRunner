const BASE_URL = `${import.meta.env.VITE_API_URL ?? ""}/api`;
export const SESSION_EXPIRED_EVENT = "jr:session-expired";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details: unknown = null,
  ) {
    super(message);
  }

  /** Serwer lub połączenie nie działa, więc dane można pobrać ponownie później. */
  get isUnavailable(): boolean {
    return this.status === 0 || this.status >= 500;
  }
}

interface Options {
  method?: "GET" | "POST" | "PATCH";
  body?: unknown;
  /** Brak sesji jest tu oczekiwany, np. przy logowaniu i pierwszym sprawdzeniu stanu konta. */
  allowAnonymous?: boolean;
}

export async function api<T>(path: string, { method = "GET", body, allowAnonymous = false }: Options = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(BASE_URL + path, {
      method,
      credentials: "include",
      headers: body === undefined ? undefined : { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, "network_error", "Brak połączenia z serwerem.");
  }

  if (response.status === 204) return undefined as T;

  const payload = await response.json().catch(() => null);
  if (response.ok) return payload as T;

  const error = payload?.error;
  if (response.status === 401 && !allowAnonymous) window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
  throw new ApiError(
    response.status,
    error?.code ?? "unknown_error",
    error?.message ?? "Wystąpił błąd. Spróbuj ponownie.",
    error?.details ?? null,
  );
}
