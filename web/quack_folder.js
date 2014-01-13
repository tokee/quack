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

// Locates an inner div with a link to the given href, then moved it to the last
// position in the given div
function moveToEnd(div, href) {
    var inners = div.getElementsByTagName('div');
    for (var i = 0 ; i < inners.length ; i++) {
        var inner = inners[i];
        var tlinks = inner.getElementsByTagName('a');
        if (tlinks.length > 0) {
            var tlink = tlinks[0];
            if (tlink.href == href) {
                inner.parentNode.appendChild(inner);
                return;
            }
        }
    }
}

// Iterates the rows in the table, collecting links to image pages.
// For each link, moveToEnd is called for the thumbs and the histograms div,
// thereby synchronicing the thumbnails and histograms to the order of the 
// images in the table.
function thClick() {
    var thumbss = document.getElementsByClassName('thumbs');
    if (thumbss.length != 1) {
        console.log('thClick: Expected 1 div.thumbs but got ' + thumbss.length);
        return;
    }
    var thumbs = thumbss[0];

    var histss = document.getElementsByClassName('histograms');
    if (histss.length != 1) {
        console.log('thClick: Expected 1 div.histograms but got ' + histss.length);
        return;
    }
    var hists = histss[0];

    // TODO: Order the image divs like the table links are ordered
    var tables = document.getElementsByClassName('sortable');
    for (var i = 0 ; i < tables.length ; i++) {
        var stable = tables[i];
        var trows = stable.getElementsByTagName('tr');
        for (var t = 0 ; t < trows.length ; t++) {
            var trow = trows[t];
            var tcells = trow.getElementsByTagName('td');
            if (tcells.length > 0) {
                var tcell = tcells[0];
                var tlinks = tcell.getElementsByTagName('a');
                if (tlinks.length > 0) {
                    var tlink = tlinks[0];
                    moveToEnd(thumbs, tlink.href);
                    moveToEnd(hists, tlink.href);
                }
            }
        }
    }
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
            thead.onclick = thClick;
        }
    }
}
window.onload = initialSetup;
