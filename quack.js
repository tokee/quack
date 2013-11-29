//! Toggling of grid and overlays

function toggleGrid() {
    
    if (document.getElementById('toggle_grid').checked) {
        state = 'block';
    } else {
        state = 'none';
    }
    
    var content = document.getElementsByClassName('gridline');
    for (var i = 0 ; i < content.length ; i++) {
        content[i].style.display = state;
    }
}

function toggleBlown() {
    if (document.getElementById('toggle_blown').checked) {
        opacity = 100;
    } else {
        opacity = 0;
    }
    
    for (var i = 0; i < myDragon.overlays.length; i++) {
        var id = myDragon.overlays[i].id;
        if ( id == 'black' || id == 'white' ) {
            OpenSeadragon.setElementOpacity(id, opacity, false);
        }
    }

    if (document.getElementById('toggle_blown').checked) {
        state = 'block';
    } else {
        state = 'none';
    }
    
    var content = document.getElementsByClassName('whiteoverlay');
    for (var i = 0 ; i < content.length ; i++) {
        if (content[i].style.backgroundImage == '' && state == 'block') {
            content[i].style.backgroundImage = "url('" + whiteoverlayurl + "')";
        }
        content[i].style.display = state;
    }
    var content = document.getElementsByClassName('blackoverlay');
    for (var i = 0 ; i < content.length ; i++) {
        if (content[i].style.backgroundImage == '' && state == 'block') {
            content[i].style.backgroundImage = "url('" + blackoverlayurl + "')";
        }
        content[i].style.display = state;
    }
}

function toggleTextBlock() {
    if (document.getElementById('toggle_textblock').checked) {
        opacity = 100;
    } else {
        opacity = 0;
    }
    
    for (var i = 0; i < myDragon.overlays.length; i++) {
        var id = myDragon.overlays[i].id;
        if ( id == 'black' || id == 'white' ) {
            continue;
        }
        OpenSeadragon.setElementOpacity(id, opacity, false);
    }
}

var ocrs = {};
var nexts = {};
var prevs = {};

// Fill in OCR for blocks with
// ocrs["BLOCK1"] = "MyOCR";
// On the preview page

function addForward(overlay, className) {
    if (!document.getElementById(overlay)) return;
    document.getElementById(overlay).className = document.getElementById(overlay).className + ' ' + className;
    if (overlay in nexts) {
        addForward(nexts[overlay], className);
    }
}
function addBackward(overlay, className) {
    if (!document.getElementById(overlay)) return;
    document.getElementById(overlay).className = document.getElementById(overlay).className + ' ' + className;
    if (overlay in prevs) {
        addBackward(prevs[overlay], className);
    }
}
function removeForward(overlay, className) {
    if (!document.getElementById(overlay)) return;
    document.getElementById(overlay).className = document.getElementById(overlay).className.replace(' ' + className, '');
    if (overlay in nexts) {
        removeForward(nexts[overlay], className);
    }
}
function removeBackward(overlay, className) {
    if (!document.getElementById(overlay)) return;
    document.getElementById(overlay).className = document.getElementById(overlay).className.replace(' ' + className, '');
    if (overlay in prevs) {
        removeBackward(prevs[overlay], className);
    }
}
function inOverlay(overlay) {
    document.getElementById('idbox').innerHTML = 'ID: ' + overlay;
    if (overlay in nexts) {
        document.getElementById('idnextbox').innerHTML = 'IDNEXT: ' + nexts[overlay];
    } else {
        document.getElementById('idnextbox').innerHTML = 'IDNEXT: ';
    }
    
    if (overlay in ocrs) {
        document.getElementById('ocrbox').innerHTML = ocrs[overlay];
    } else {
        document.getElementById('ocrbox').innerHTML = '';
    }
    addForward(overlay, "group");
//    addForward(overlay, "next");
    addBackward(overlay, "group");
    if (overlay in nexts) {
        document.getElementById(nexts[overlay]).className = document.getElementById(nexts[overlay]).className + ' next';
    }
}
function outOverlay(overlay) {
    document.getElementById('ocrbox').innerHTML = '';
    document.getElementById('idnextbox').innerHTML = 'IDNEXT: ';
    document.getElementById('idbox').innerHTML = 'ID: ';

    removeForward(overlay, "group");
    removeForward(overlay, "next");
    removeBackward(overlay, "group");
    removeBackward(overlay, "next");
}

function setupJS() {
    // TODO: Check if this is an image page and if not, exit immediately

    toggleGrid();
    toggleTextBlock();
    toggleBlown();
    
    //! Create a callback for eack overlay with the overlay-ID as argument
    for (var i = 0; i < myDragon.overlays.length; i++) {
        id = myDragon.overlays[i].id;
        shortid = id.split("/").pop();
        if ( id == 'white' || id == 'black' ) {
            continue;
        }

        o = document.getElementById(id);
        o.onmouseover = new Function('inOverlay("' + shortid + '")');
        o.onmouseout = new Function('outOverlay("' + shortid + '")');
    }

    // Try to disable fancy interpolation
    var canvases = document.getElementsByTagName("canvas");
    for(var i = 0; i < canvases.length; i++){
        canvases[i].style.imageRendering = "-moz-crisp-edges";
        canvases[i].getContext.mozImageSmoothingEnabled = false;
    }
}
window.onload=setupJS;

