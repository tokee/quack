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
//    console.log("Overlay " + overlay + " now has className " + document.getElementById(overlay).className);
    if (overlay in nexts) {
//    console.log("Adding to next " + nexts[overlay] + " for " + overlay);
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

// URL parameter parsing
// http://stackoverflow.com/questions/979975/how-to-get-the-value-from-url-parameter
function getRes() {
    var input = window.location.href;
//    name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");  
//    var regexS = "/[\\?&]" + name + "=([^&#]*)/g";  
//    var regex = new RegExp( regexS );  
    var regex = /[\\?&]box=([^&#]*)/g;  
    var results = [];

    var tokens;
    while (tokens = regex.exec(input)) { 
        results.push(decodeURIComponent(tokens[1]));
//        console.log('Pushing ' + decodeURIComponent(tokens[1]));
    }
    return results;
}


function createDiv(id, className, content) {
    var msgContainer = document.createElement('div');
    msgContainer.id = id;               // No setAttribute required
    msgContainer.className = className; // No setAttribute required, note it's "className" to avoid conflict with JavaScript reserved word
    msgContainer.appendChild(document.createTextNode(content));
    document.body.appendChild(msgContainer);
    return msgContainer;
}

// Helper for addResultBoxes that constructs a single box
// 0.036886,0.740071 0.898778x0.108414 I BYEN MED DE KENDTE
var boxCounter = 0;
function addResultBox(boxData) {
//    console.log('Processing box ' + boxData);
    var parts = boxData.split(' ');
    var x = parseFloat(parts[0].split(',')[0]);
    var y = parseFloat(parts[0].split(',')[1]);
    var w = parseFloat(parts[1].split('x')[0]);
    var h = parseFloat(parts[1].split('x')[1]);
    var content = '';
    for (var i = 2 ; i < parts.length ; i++) {
        if (i > 2) {
            content += ' ';
        }
        content += parts[i];
    }
    console.log('Creating overlay box for x=' + x + ', y=' + y + ', w=' + w + ', h=' + h + ', content=' + content);
    myDragon.drawer.addOverlay(createDiv('searchresult' + boxCounter++, 'searchresultbox', content), new OpenSeadragon.Rect(x, y, w, h), OpenSeadragon.OverlayPlacement.TOP_LEFT, '');
}

// Looks for attributes with the name 'box'. A box contains x,y in relative coordinates,
// width x height i relative coordinates and optional context for the box. Sample:
// 0.036886,0.740071 0.898778x0.108414 I BYEN MED DE KENDTE
function addResultBoxes() {
    var results = getRes();
//    document.title = document.title + ' ' + results + ' (length ' + results.length + ')';
    for (var i = 0; i < results.length; i++) {
        addResultBox(results[i]);
    }
}

// Mark all groups (articles linked with IDNEXT) with class g$COUNT, starting from 1
function colorGroups() {
    console.log('Coloring groups started');
    var count=1
    for (var i = 0; i < myDragon.overlays.length; i++) {
        var id = myDragon.overlays[i].id;
        var element = document.getElementById(id);
        if (element == null) {
            console.log('Unable to get element with id ' + id);
            continue;
        }

  //      element.className = element.className + ' g' + count;
 //       count++;
 //       continue;

        if (('highlight' == element.className) && (id in nexts)) {
//            console.log('id ' + id + ' was in nextx: ' + id + " " + nexts[id] + " with old className=" + element.className);
            addForward(id, "g" + count);
            count++;
        }
    }
    console.log('Coloring groups finished');
}
 
function setupJS() {
    // TODO: Check if this is an image page and if not, exit immediately
    colorGroups();
    toggleGrid();
    toggleTextBlock();
    toggleBlown();
//    addResultBoxes();

    // Create a callback for eack overlay with the overlay-ID as argument
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

    // Enable interaction with OpenSeadragon
    var content = document.getElementsByClassName('passive');
    for (var i = 0 ; i < content.length ; i++) {
        content[i].className = content[i].className.replace(' passive', '');
    }    
}
function setupJSDelay() {
    // We need to have the OpenSeadragon overlays in place
    // TODO: Make this a callback from OpenSeadragon instead
    window.setTimeout(setupJS, 500);
}
//window.onload=setupJS;
window.onload=setupJSDelay;

