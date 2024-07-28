export function updateSearchParams(id: string, value: string) {
  if ("URLSearchParams" in window) {
    const url = new URL(window.location.toString());
    url.searchParams.set(id, value);
    history.pushState(null, "", url);
  }
}
