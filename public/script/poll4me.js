
/**
 * Get a callback function (event handler) to add an answer form field to the page in response to a click event
 *
 * @param answer_index - the answer index of the first answer to be appended (this will be updated within the function's scope with each added answer)
 * @param tabindex - the tabindex of the first answer's form field (this will be updated within the function's scope with each added answer)
 * @param append_to - the jquery selector for the element to which to append the new element
 * @return a function with no parameters that can be used as an event handler for click events
 */
function add_answer_callback(answer_index, tabindex, append_to) {
    return function() {
        var li = $(append_to + ' li:first-child').clone(true); 
        li.find('input').attr('id', 'answer_' + answer_index).attr('tabindex', tabindex);
        li.appendTo(append_to);
        $('#answer_' + answer_index).focus();
        answer_index++;
        tabindex++;
    }
}

