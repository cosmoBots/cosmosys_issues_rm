var coll = document.getElementsByClassName("collapsible");
var i;

for (i = 0; i < coll.length; i++) {
  coll[i].addEventListener("click", function() {
    this.classList.toggle("active");
    var content = this.nextElementSibling;
    if (content.style.maxHeight){
      content.style.maxHeight = null;
    } else {
      content.style.maxHeight = content.scrollHeight + "px";
    }

    // We have to go up to recalculate the maxHeight of the 
    // ancestors
    done = false;
    while (done == false){
        done = true;
        thisEl = content.parentNode;
        if (thisEl != null){
            butEl = thisEl.previousElementSibling;
            if (butEl != null) {
                if (butEl.className == "collapsible") {
                    done = false;
                    thisEl.style.maxHeight = null;
                }
            }
        }
        content = thisEl;
    }
  });
}
