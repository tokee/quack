function toggleBlownThumbs() {    
    if (document.getElementById('toggle_blown_thumbs').checked) {
        state = 'block';
    } else {
        state = 'none';
    }
    
    var content = document.getElementsByClassName('thumboverlay');
    for (var i = 0 ; i < content.length ; i++) {
        content[i].style.display = state;
    }
}
function toggleHistograms() {  
    if (document.getElementById('toggle_histograms').checked) {
        thumb_state = 'none';
        hist_state = 'block';
    } else {
        thumb_state = 'block';
        hist_state = 'none';
    }
    
    var content = document.getElementsByClassName('thumbs');
    for (var i = 0 ; i < content.length ; i++) {
        content[i].style.display = thumb_state;
    }
    var content = document.getElementsByClassName('histograms');
    for (var i = 0 ; i < content.length ; i++) {
        content[i].style.display = hist_state;
    }
}

function thclick() {
    // Consider a timeout if there is a race condition with the table sort
    // TODO: Order the image divs like the table links are ordered
}

var oldOnload = window.onload;
function initialSetup() {
    if (oldOnload != null) {
        console.log('Calling previous onLoad');
        oldOnload();
    }
    // Thumb overlays
    console.log('Adding thumb overlays');
    var content = document.getElementsByClassName('thumblink');
    for (var i = 0 ; i < content.length ; i++) {
        var href = content[i].href;
        var span = content[i].getElementsByClassName('thumboverlay')[0];
        var img = content[i].getElementsByClassName('thumbimg')[0];
        var base = img.src.substr(0, img.src.lastIndexOf('.'));
        var base = base.substr(0, base.lastIndexOf('.'));
        span.style.width = img.width + "px";
        span.style.height = img.height + "px";
        span.style.background = "url(" + base + ".black.thumb.png) 100% 100%, url(" + base + ".white.thumb.png) 100% 100%";
        document.title = span.style.background;
    }

    console.log('Attaching hooks for table sort');
    var tables = document.getElementsByClassName('sortable');
    for (var i = 0 ; i < tables.length ; i++) {
        var stable = tables[i];
        var theads = stable.getElementsByTagName('th');
        for (var h = 0 ; h < theads.length ; h++) {
            thead = theads[h];
            thead.onclick = thclick;
        }
    }
}
window.onload = initialSetup;
