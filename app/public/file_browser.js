window.addEventListener("load", function() {
	function getPath() {
		return new Promise(function(resolve, reject) {
			var template = document.getElementById("file-browser-template").innerHTML;
			var browser = document.getElementById("file-browser");
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
					browser.innerHTML = Mustache.render(template, json);

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
							resolve(link.dataset.path);
							browser.innerHTML = "";
						}
					});
				});
			}

			function merge(one, two) {
				merged = JSON.parse(JSON.stringify(one));
				for(key in two) { merged[key] = two[key]; }
				return merged;
			}

			// TODO: remove hardcoded route
			directoryListing("/3/files");
		});
	}

	Array.prototype.forEach.call(document.querySelectorAll("input[type='file']"), function(fileInput) {
		fileInput.addEventListener("click", function(event) {
			event.preventDefault();
			getPath().then(function(path) {
				fileInput.previousElementSibling.value = path;
			});
		});
	});
});
