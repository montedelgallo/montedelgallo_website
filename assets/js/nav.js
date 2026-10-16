// Mobile menu toggle. Below 860px the header links live in #site-menu, which the
// stylesheet collapses only when the page carries <html class="js"> (set by the
// head script), so without JavaScript the links stay open and reachable.
//
// The button (.nav__toggle) controls the menu through aria-controls and mirrors the
// state in aria-expanded. Escape closes the menu and puts focus back on the button;
// following a link closes it; widening the window to the desktop layout resets it.
(function () {
  var button = document.querySelector('.nav__toggle');
  if (!button) return;
  var menu = document.getElementById(button.getAttribute('aria-controls'));
  if (!menu) return;
  var narrow = window.matchMedia('(max-width: 860px)');

  function isOpen() {
    return button.getAttribute('aria-expanded') === 'true';
  }

  function setOpen(open, returnFocus) {
    button.setAttribute('aria-expanded', open ? 'true' : 'false');
    button.setAttribute('aria-label', button.getAttribute(open ? 'data-label-close' : 'data-label-open'));
    menu.classList.toggle('is-open', open);
    if (!open && returnFocus) button.focus();
  }

  button.addEventListener('click', function () {
    setOpen(!isOpen(), false);
  });

  document.addEventListener('keydown', function (event) {
    if ((event.key === 'Escape' || event.key === 'Esc') && isOpen()) {
      setOpen(false, true);
    }
  });

  menu.addEventListener('click', function (event) {
    var node = event.target;
    while (node && node !== menu) {
      if (node.tagName === 'A') {
        setOpen(false, false);
        return;
      }
      node = node.parentNode;
    }
  });

  function onResize() {
    if (!narrow.matches && isOpen()) setOpen(false, false);
  }
  if (narrow.addEventListener) narrow.addEventListener('change', onResize);
  else if (narrow.addListener) narrow.addListener(onResize);
})();
