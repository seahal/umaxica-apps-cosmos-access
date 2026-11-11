/**
 * The text an element actually names through `aria-describedby`, resolved id by id.
 *
 * Asserting on the resolved text rather than on the attribute is what proves the association: an
 * `aria-describedby` pointing at an id nothing carries announces nothing.
 */
export function describedByText(element: Element): string {
  return (element.getAttribute("aria-describedby") ?? "")
    .split(" ")
    .filter(Boolean)
    .map((id) => document.querySelector(`#${id}`)?.textContent ?? "")
    .join(" ");
}
