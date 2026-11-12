{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({config: {
  canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  fontFallbackBaseUrl: new URL('assets/fonts/fallback/', document.baseURI).href,
}});

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => {
    if (!navigator.onLine) return;
    fetch(new URL('moneymate-sw.js', document.baseURI), {cache: 'no-store'}).then(response => {
      if (response.ok && response.headers.get('content-type')?.includes('javascript')) {
        return navigator.serviceWorker.register(new URL('moneymate-sw.js', document.baseURI));
      }
    }).catch(error => console.warn('MoneyMate offline cache could not be prepared.', error));
  });
}
