// Answering `fetch` from a spec, and reading back what the code under test sent.
//
// `RequestInit["body"]` is a union that includes streams and form data, so reading it needs a
// narrowing step rather than a `String(...)` that would quietly answer "[object Object]" for the
// shapes this application never sends. Doing that once here keeps every spec's assertion honest.
import { vi } from "vitest";

export type FetchMock = { mock: { calls: Parameters<typeof fetch>[] } };

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/**
 * A response the code under test must handle without parsing it as JSON. `contentType` is optional
 * because a server behind a proxy can answer with none at all, and that path needs covering too.
 */
export function textResponse(body: string, status: number, contentType = "text/html"): Response {
  return new Response(body, {
    status,
    ...(contentType === "" ? {} : { headers: { "content-type": contentType } }),
  });
}

function urlOf(target: Parameters<typeof fetch>[0]): string {
  if (typeof target === "string") {
    return target;
  }

  return target instanceof URL ? target.href : target.url;
}

function jsonBody(init: RequestInit | undefined): unknown {
  const { body } = init ?? {};

  if (typeof body !== "string") {
    throw new TypeError(`Expected the request body to be a JSON string, got ${typeof body}.`);
  }

  return JSON.parse(body);
}

/** The parsed JSON body of the nth request, in the order the code under test made them. */
export function requestBody(fetchMock: FetchMock, index = 0): unknown {
  return jsonBody(fetchMock.mock.calls[index]?.[1]);
}

/** The url of the nth request. */
export function requestUrl(fetchMock: FetchMock, index = 0): string {
  const call = fetchMock.mock.calls[index];

  if (!call) {
    throw new Error(`No request was made at index ${index}.`);
  }

  return urlOf(call[0]);
}

/** Installs a `fetch` that answers the queued responses in order, then repeats the last one. */
export function stubFetchQueue(...responses: Response[]) {
  const fetchMock = vi.fn<typeof fetch>();
  responses.forEach((response) => fetchMock.mockResolvedValueOnce(response));
  const last = responses.at(-1);
  if (last) {
    fetchMock.mockResolvedValue(last);
  }
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}
