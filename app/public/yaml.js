window.addEventListener("load", function() {
	function forEach(collection, operation) {
		Array.prototype.forEach.call(collection, operation);
	}

	function find(collection, condition) {
		return Array.prototype.find.call(collection, condition);
	}

	function nameRegexp(ol) {
		return new RegExp(ol.dataset.key.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") + "\\[\\d+\\]");
	}

	function buildName(string, ol, number) {
		return string.replace(nameRegexp(ol), ol.dataset.key + "[" + number + "]");
	}

	function enableDisableMoveButtons(ol, li, number) {
		find(li.children, function(el) { return el.className === "move-up"; }).disabled = number < 1;
		find(li.children, function(el) { return el.className === "move-down"; }).disabled = number >= ol.children.length - 1;
	}

	function hydrateLi(li) {
		function findOrCreateButton(className, label) {
			var button = find(li.children, function(el) { return el.className === className; });

			if(!button) {
				button = document.createElement("button");
				li.appendChild(button);

				button.type = "button";
				button.className = className;
				button.textContent = label;
			}

			return button;
		}

		findOrCreateButton("clone", "Clone").addEventListener("click", function() {
			var item = li.cloneNode(true);
			renameAppendHydrate(li.parentElement, item, nameRegexp(li.parentElement));
		});

		findOrCreateButton("move-up", "▲").addEventListener("click", function() {
			li.parentNode.insertBefore(li, li.previousElementSibling);
			renumber(li.parentNode, li);
			renumber(li.parentNode, li.nextElementSibling);
		});

		findOrCreateButton("move-down", "▼").addEventListener("click", function() {
			li.parentNode.insertBefore(li.nextElementSibling, li);
			renumber(li.parentNode, li);
			renumber(li.parentNode, li.previousElementSibling);
		});

		enableDisableMoveButtons(li.parentNode, li, Array.prototype.indexOf.call(li.parentNode.children, li));

		forEach(li.querySelectorAll("input[type=file]"), function(fileInput) {
			// We should only hydrate "direct" children that are not in a
			// descendant ol[data-key]
			var traverseParents = fileInput.parentElement;
			while(traverseParents.nodeName !== "OL" && !traverseParents.dataset.key) {
				traverseParents = traverseParents.parentElement;
			}

			if(traverseParents === li.parentElement) {
				fileBrowser(fileInput);
			}
		});
	}

	function renumber(ol, li) {
		var number = Array.prototype.indexOf.call(ol.children, li);

		if(number === -1) {
			number = ol.children.length;
		}

		forEach(li.querySelectorAll('input, textarea, select'), function(el) {
			el.name = buildName(el.name, ol, number);
		});

		forEach(li.querySelectorAll('ol[data-key]'), function(el) {
			el.dataset.key = buildName(el.dataset.key, ol, number);
		});

		enableDisableMoveButtons(ol, li, number);
	}

	function renameAppendHydrate(ol, item, resetValue) {
		renumber(ol, item);

		if(resetValue) {
			forEach(item.querySelectorAll('input, textarea, select'), function(el) {
				el.value = '';
			});

			forEach(item.querySelectorAll("input[type='file']"), function(input) {
				var image = input.previousElementSibling.previousElementSibling.nodeName === "IMG" &&
										input.previousElementSibling.previousElementSibling;

				if(image) {
					image.parentNode.removeChild(image);
				}
			});
		}

		forEach(item.querySelectorAll('ol[data-key]'), function(el) {
			hydrate(el);
		});

		ol.appendChild(item);
		hydrateLi(item);

		if(item.getBoundingClientRect().bottom > window.innerHeight) {
			item.scrollIntoView(false);
		}
	}

	function hydrate(ol) {
		var button = ol.parentElement.lastElementChild;
		button.addEventListener("click", function() {
			var item = ol.lastElementChild.cloneNode(true);
			forEach(item.querySelectorAll('ol > li:not(:first-of-type)'), function(el) {
				el.parentNode.removeChild(el);
			});

			renameAppendHydrate(ol, item, true)
		});

		forEach(ol.children, function(li, i) {
			hydrateLi(li);
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
