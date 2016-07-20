window.addEventListener("load", function() {
	function hydrate(ol) {
		var nameRegexp = new RegExp(ol.dataset.key.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + "\\[\\d+\\]");
		var button = ol.parentElement.lastElementChild;
		button.addEventListener("click", function() {
			var item = ol.lastElementChild.cloneNode(true);
			Array.prototype.forEach.call(item.querySelectorAll('ol > li:not(:first-of-type)'), function(el) {
				el.parentNode.removeChild(el);
			});

			Array.prototype.forEach.call(item.querySelectorAll('input, textarea'), function(el) {
				el.name = el.name.replace(nameRegexp, ol.dataset.key + "[" + ol.children.length + "]");
				el.value = '';
			});

			Array.prototype.forEach.call(item.querySelectorAll('ol[data-key]'), function(el) {
				el.dataset.key = el.dataset.key.replace(nameRegexp, ol.dataset.key + "[" + ol.children.length + "]")
				hydrate(el);
			});

			ol.appendChild(item);
		});
	}

	Array.prototype.forEach.call(document.querySelectorAll("form ol[data-key]"), function(ol) {
		var button = document.createElement("button");
		button.type = "button";
		button.textContent = "New Item";
		ol.parentElement.appendChild(button);
		hydrate(ol);
	});

	var hidden = document.querySelectorAll("form .hidden");
	Array.prototype.forEach.call(hidden, function(el) { el.style.display = 'none'; });
});
