window.addEventListener("load", function() {
	Array.prototype.forEach.call(document.querySelectorAll(".files input[name=name]"), function(el) {
		el.style.display = "none";

		el.parentElement.addEventListener("submit", function(e) {
			if(el.style.display === "none") {
				e.preventDefault();
				el.style.display = "inline-block";
			}
		});
	});
});
