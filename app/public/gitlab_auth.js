window.addEventListener("load", function() {
	function showHideInputs(showHide) {
		Array.prototype.forEach.call(document.querySelectorAll("#other-gitlab input"), function(el) {
			el.style.display = showHide;
		});
	}

	showHideInputs("none");

	document.querySelector("#other-gitlab").addEventListener("submit", function(e) {
		if(document.querySelector("#other-gitlab input").style.display === "none") {
			e.preventDefault();
			showHideInputs("block");
		}
	});
});
