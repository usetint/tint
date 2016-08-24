//= require vendor/moment
//= require vendor/moment-strftime-0.1.2

window.addEventListener("load", function() {
  Array.prototype.forEach.call(document.querySelectorAll('time[data-strftime]'), function(time) {
    var datetime = moment(time.getAttribute("datetime"));
    var strftime = time.dataset.strftime;

		time.textContent = datetime.strftime(strftime);
	});
});
