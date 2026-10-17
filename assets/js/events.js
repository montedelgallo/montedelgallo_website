// Conversion events for the cookieless analytics (_includes/analytics.html loads this file
// only when a provider is configured).
//
// The markup declares an event on an element: data-track="book_call_click" and
// data-track-location="header_bar" (where on the page it is). A click on (or inside) such a
// link, or the submit of such a form, is reported to whichever provider is on the page:
// Plausible (window.plausible) or Umami (window.umami.track). If neither is there (blocked,
// not loaded yet), nothing happens.
//
// It only LISTENS: it never cancels, delays or replaces the click or the submit, so the visit
// to the booking page and the POST of the contact form happen exactly as without it. The
// provider's own script does the sending. No cookie, no storage, nothing about the visitor
// is read: the event name and the place on the page, that is all.
(function () {
  function report(el) {
    try {
      var name = el.getAttribute('data-track');
      var location = el.getAttribute('data-track-location');
      if (!name) return;
      if (typeof window.plausible === 'function') {
        window.plausible(name, { props: { location: location || '' } });
      } else if (window.umami && typeof window.umami.track === 'function') {
        window.umami.track(name, { location: location || '' });
      }
    } catch (e) {
      // analytics must never break the page
    }
  }

  function tracked(event) {
    var target = event && event.target;
    return target && typeof target.closest === 'function' ? target.closest('[data-track]') : null;
  }

  function isForm(el) {
    return !!el.tagName && el.tagName.toLowerCase() === 'form';
  }

  // A form is reported when it is submitted, not when its button is clicked.
  document.addEventListener('click', function (event) {
    var el = tracked(event);
    if (el && !isForm(el)) report(el);
  });

  // A middle click opens the link in a new tab without a click event.
  document.addEventListener('auxclick', function (event) {
    var el = tracked(event);
    if (el && !isForm(el) && event.button === 1) report(el);
  });

  document.addEventListener('submit', function (event) {
    var el = tracked(event);
    if (el && isForm(el)) report(el);
  });
})();
