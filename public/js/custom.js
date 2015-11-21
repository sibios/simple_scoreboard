window.setTimeout(function() {
    $(".alert-danger,.alert-success").fadeTo(500, 0).slideUp(500, function(){
        $(this).remove(); 
    });
}, 5000);
