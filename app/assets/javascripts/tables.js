/*
 Extending JQuery with some useful plugin
*/
/* Table Scroller */

/*
	Helper methods
*/

function Tables_setLiveFilter(table_id, search_box){
	$(search_box).quicksearch(table_id+'tr');
	
	$(search_box).keydown(function(event){
	    if(event.keyCode == 13) {
	      event.preventDefault();
	      return false;
	    }
	});
}

function Tables_setLiveSorting(table_id){
	$(table_id).tablesorter();
}
