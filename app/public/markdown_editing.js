window.addEventListener('load', function() {
	var content = document.querySelector('textarea[name=content]');
	content.value = marked(content.value.replace(/\t/, "&#9;"));
	tinymce.init({
		selector: 'textarea[name=content]',
		menubar: false,
		statusbar: false,
		toolbar: 'undo redo | formatselect | bold italic numlist bullist | blockquote link image',
		entity_encoding: 'raw',
		plugins: "autoresize, link",
		document_base_url: "http://" + site_domain + "/",
		relative_urls: false,
		remove_script_host: true,
		target_list: false,
		link_title: false,
		// Can have a link_list that gets links from JSON, URL, or function and displays

		// Show and preserve whitspace
		whitespace_elements: 'p',
		content_style: 'p { white-space: pre-wrap; }'
	});

	document.querySelector("form#content").addEventListener("submit", function(e) {
		var form = this;
		e.preventDefault();

		new upndown().convert(content.value, function(error, markdown) {
			if(error) {
				alert(error);
			} else {
				content.value = markdown;
				HTMLFormElement.prototype.submit.call(form);
			}
		}, { keepHtml: true, keepWhitespace: true });
	});
});
