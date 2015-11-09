//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .

$(document).on('ajax:complete', '.js-vote-button', function(_, xhr){
  $(".voting").html(xhr.responseJSON.error);
  $(".vote-count").html(xhr.responseJSON.votes);
});
