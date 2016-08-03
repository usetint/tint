window.addEventListener('load', function() {
	var content = document.querySelector('textarea[name=content]');
	content.value = marked(content.value.replace(/\t/, "&#9;"));
	tinymce.init({
		selector: 'textarea[name=content]',
		menubar: false,
		toolbar: 'undo redo | formatselect | bold italic numlist bullist | blockquote link image',
		entity_encoding: 'raw',

		// Show and preserve whitspace
		whitespace_elements: 'p',
		content_style: 'p { white-space: pre-wrap; }'
	});

	document.querySelector("form").addEventListener("submit", function(e) {
		e.preventDefault();

		new upndown().convert(content.value, function(error, markdown) {
			if(error) {
				alert(error);
			} else {
				content.value = markdown;
				HTMLFormElement.prototype.submit.call(document.querySelector("form"));
			}
		}, { keepHtml: true, keepWhitespace: true });
	});
});
