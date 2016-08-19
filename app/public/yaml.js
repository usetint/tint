window.addEventListener("load", function() {
	function forEach(collection, operation) {
		Array.prototype.forEach.call(collection, operation);
	}

	function find(collection, condition) {
		return Array.prototype.find.call(collection, condition);
	}

	function buildName(string, ol, nameRegexp) {
		return string.replace(nameRegexp, ol.dataset.key + "[" + ol.children.length + "]");
	}

	function hydrateLi(nameRegexp, li, i) {
		var ol = li.parentElement;
		var button = find(li.children, function(el) { return el.className === "clone"; });

		if(!button) {
			button = document.createElement("button");
			li.appendChild(button);

			button.type = "button";
			button.className = "clone";
			button.textContent = "Clone";
		}

		button.addEventListener("click", function() {
			var item = li.cloneNode(true);
			renameAppendHydrate(ol, item, nameRegexp);
		});

		forEach(li.querySelectorAll("input[type='file']"), function(input) {
			input.addEventListener("change", function() {
				if (input.files && input.files[0]) {
					var reader = new FileReader();

					reader.onload = function (e) {
						var image = input.previousElementSibling.previousElementSibling.nodeName === "IMG" &&
												input.previousElementSibling.previousElementSibling;

						if(!image) {
							image = document.createElement("img");
							input.parentElement.insertBefore(image, input);
						}

						image.src = e.target.result;
					}

					reader.readAsDataURL(input.files[0]);
				}
			});
		});
	}

	function renameAppendHydrate(ol, item, nameRegexp, resetValue) {
		forEach(item.querySelectorAll('input, textarea'), function(el) {
			el.name = buildName(el.name, ol, nameRegexp);
			if(resetValue) {
				el.value = '';
			}
		});

		if(resetValue) {
			forEach(item.querySelectorAll("input[type='file']"), function(input) {
				var image = input.previousElementSibling.nodeName === "IMG" &&
										input.previousElementSibling;

				if(image) {
					image.parentNode.removeChild(image);
				}
			});
		}

		forEach(item.querySelectorAll('ol[data-key]'), function(el) {
			el.dataset.key = buildName(el.dataset.key, ol, nameRegexp);
			hydrate(el);
		});

		ol.appendChild(item);
		hydrateLi(nameRegexp, item, ol.children.length - 1);

		if(item.getBoundingClientRect().bottom > window.innerHeight) {
			item.scrollIntoView(false);
		}
	}

	function hydrate(ol) {
		var nameRegexp = new RegExp(ol.dataset.key.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + "\\[\\d+\\]");
		var button = ol.parentElement.lastElementChild;
		button.addEventListener("click", function() {
			var item = ol.lastElementChild.cloneNode(true);
			forEach(item.querySelectorAll('ol > li:not(:first-of-type)'), function(el) {
				el.parentNode.removeChild(el);
			});

			renameAppendHydrate(ol, item, nameRegexp, true)
		});

		forEach(ol.children, function(li, i) {
			hydrateLi(nameRegexp, li, i);
		});
	}

	forEach(document.querySelectorAll("form ol[data-key]"), function(ol) {
		var button = document.createElement("button");
		button.type = "button";
		button.textContent = "New Item";
		ol.parentElement.appendChild(button);
		hydrate(ol);
	});

	var hidden = document.querySelectorAll("form .hidden");
	forEach(hidden, function(el) { el.style.display = 'none'; });

});
