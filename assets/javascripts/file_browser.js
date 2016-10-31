//= require templates/file_browser

window.addEventListener("load", function() {
	function getFileDetails() {
		return new Promise(function(resolve, reject) {
			var modal = document.createElement("div");
			modal.setAttribute("id", "file-browser");

			function cancelOnEsc(e) {
				document.removeEventListener("keyup", cancelOnEsc);

				if(e.key === "Escape") {
					reject("cancel");
					modal.parentElement.removeChild(modal);
				}
			}

			modal.addEventListener("click", function(e) {
				if(e.target === modal) {
					document.removeEventListener("keyup", cancelOnEsc);
					reject("cancel");
					modal.parentElement.removeChild(modal);
				}
			});

			document.addEventListener("keyup", cancelOnEsc);

			var browser = document.createElement("div");
			browser.className = "contents";
			modal.appendChild(browser);
			document.body.appendChild(modal)

			modal.style.display = "flex";

			var headers = new Headers();
			headers.append('Accept', 'application/json');
			var params = {
				credentials: "include",
				headers: headers
			}

			function directoryListing(route) {
				fetch(route, params).then(function(response) {
					return response.json();
				}).then(function(json) {
					browser.innerHTML = JST["templates/file_browser"](
						merge(json, { route: route })
					);

					bindUpload(browser.querySelector("form"));
					bindLinks(browser.querySelectorAll("a"));
				});
			}

			function bindUpload(form) {
				form.addEventListener("submit", function(event) {
					event.preventDefault();

					var fileInput = form.querySelector("input[type='file']");
					var data = new FormData();
					data.append("file", fileInput.files[0]);

					fetch(form.action, merge(params, {
						method: "POST",
						body: data
					})).then(function(response) {
						directoryListing(form.action);
					});
				});
			}

			function bindLinks(links) {
				Array.prototype.forEach.call(browser.querySelectorAll("a"), function(link) {
					link.addEventListener("click", function(event) {
						event.preventDefault();

						if(link.dataset.type === "directory") {
							directoryListing(link.href);
						} else {
							resolve({
								path: link.dataset.path,
								route: link.href,
								mime: link.dataset.mime
							});
							document.removeEventListener("keyup", cancelOnEsc);
							modal.parentElement.removeChild(modal);
						}
					});
				});
			}

			function merge(one, two) {
				merged = Object.create(one);
				for(key in two) {
					if(two.hasOwnProperty(key)) { merged[key] = two[key]; }
				}
				return merged;
			}

			directoryListing(files_path);
		});
	}

	Array.prototype.forEach.call(document.querySelectorAll(".yml input[type='file']"), function(fileInput) {
		var pathInput = fileInput.previousElementSibling;

		var button = document.createElement("button");
		button.type = "button";
		button.textContent = "Choose File";

		fileInput.parentElement.insertBefore(button, fileInput.nextSibling);

		fileInput.style.display = "none";
		pathInput.style.display = "none";

		button.addEventListener("click", function(event) {
			event.preventDefault();
			getFileDetails().then(function(details) {
				fileInput.previousElementSibling.value = details.path;
				replaceFilePreview(
					fileInput,
					details.mime.split("/")[0] === "image" ? "IMG" : "DIV",
					details.route,
					details.path
				);
			}, function(error) {
				if(error !== "cancel") {
					alert("" + error);
				}
			});
		});
	});

	function replaceFilePreview(input, nodeName, src, alt) {
		var valueEl = input.previousElementSibling.previousElementSibling;

		if(valueEl.nodeName !== nodeName) {
			valueEl.parentElement.removeChild(valueEl);

			valueEl = document.createElement(nodeName);
			valueEl.className = "value";
			input.parentElement.insertBefore(valueEl, input.previousElementSibling);
		}

		if(nodeName === "IMG") {
			valueEl.src = src + "?download";
			valueEl.alt = alt;
		} else {
			valueEl.textContent = alt;
		}
	}
});
