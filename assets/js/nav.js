// Mobile menu toggle. Below 860px the header links live in #site-menu, which the
// stylesheet collapses only when the page carries <html class="js"> (set by the
// head script, so there is no flash of the open menu). Without JavaScript the links
// stay open and reachable.
//
// If this file cannot do its job, <html> swaps its js class for no-js (a classList swap: any
// other class on <html> stays) and the open menu layout returns: a menu that cannot open must
// never stay shut. Two ways in: anything below throws (giveUp, here), or the file never runs
// (it fails to load, or the browser blocks it). For the second one this file announces itself
// at the end of its setup with <html data-nav="ready">, and the inline script of head.html,
// on DOMContentLoaded (after every deferred script has run or failed), swaps back to no-js when
// that flag is missing. (There is no onerror attribute on the <script> tag: an inline event
// handler would need 'unsafe-hashes' in the Content-Security-Policy.)
//
// The button (.nav__toggle) controls the menu through aria-controls and mirrors the
// state in aria-expanded (its accessible name stays "Menu"). Escape closes the menu
// and puts focus back on the button; following a link closes it; widening the window
// to the desktop layout resets it.
(function () {
  var root = document.documentElement;

  function giveUp() {
    root.classList.remove('js');
    root.classList.add('no-js');
  }

  try {
    var button = document.querySelector('.nav__toggle');
    var menu = button && document.getElementById(button.getAttribute('aria-controls'));
    if (!button || !menu) {
      giveUp();
      return;
    }
    var narrow = window.matchMedia('(max-width: 860px)');

    var isOpen = function () {
      return button.getAttribute('aria-expanded') === 'true';
    };

    var setOpen = function (open, returnFocus) {
      button.setAttribute('aria-expanded', open ? 'true' : 'false');
      menu.classList.toggle('is-open', open);
      if (!open && returnFocus) button.focus();
    };

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

    var onResize = function () {
      if (!narrow.matches && isOpen()) setOpen(false, false);
    };
    if (narrow.addEventListener) narrow.addEventListener('change', onResize);
    else if (narrow.addListener) narrow.addListener(onResize);

    // The setup is complete: tell head.html's DOMContentLoaded handler to keep the js layout.
    root.dataset.nav = 'ready';
  } catch (error) {
    giveUp();
  }
})();
