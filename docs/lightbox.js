(function () {
  function initScreenshotLightbox() {
    const frames = document.querySelectorAll(".mobile-frame img, .hardware-frame img");
    if (!frames.length) return;

    const overlay = document.createElement("div");
    overlay.className = "screenshot-lightbox";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-label", "Expanded screenshot");
    overlay.innerHTML = `
      <button type="button" class="screenshot-lightbox__close" aria-label="Close">×</button>
      <div class="screenshot-lightbox__content">
        <img class="screenshot-lightbox__image" alt="" />
        <p class="screenshot-lightbox__caption"></p>
      </div>
    `;
    document.body.appendChild(overlay);

    const image = overlay.querySelector(".screenshot-lightbox__image");
    const caption = overlay.querySelector(".screenshot-lightbox__caption");
    const closeBtn = overlay.querySelector(".screenshot-lightbox__close");

    function open(src, alt) {
      image.src = src;
      image.alt = alt;
      if (alt) {
        caption.textContent = alt;
        caption.hidden = false;
      } else {
        caption.textContent = "";
        caption.hidden = true;
      }
      overlay.classList.add("active");
      document.body.style.overflow = "hidden";
      closeBtn.focus();
    }

    function close() {
      overlay.classList.remove("active");
      document.body.style.overflow = "";
      image.removeAttribute("src");
    }

    frames.forEach((thumb) => {
      const frame = thumb.closest(".mobile-frame, .hardware-frame");
      const target = frame || thumb;
      target.addEventListener("click", () => open(thumb.src, thumb.alt));
      target.setAttribute("title", "Click to enlarge");
    });

    closeBtn.addEventListener("click", close);
    overlay.addEventListener("click", (event) => {
      if (event.target === overlay) close();
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && overlay.classList.contains("active")) close();
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initScreenshotLightbox);
  } else {
    initScreenshotLightbox();
  }
})();
