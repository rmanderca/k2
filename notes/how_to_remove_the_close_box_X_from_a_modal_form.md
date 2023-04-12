# How to Remove the "X" Close Box on Modal Forms

1. Put the following code in the "Inline" text area of the "CSS" section in the page that calls the modal dialog page:

    ```
    .no-close .ui-dialog-titlebar-close {
        display: none;
    }
    ```

2. In the modal dialog form, go to the "Dialog" attributes section and in the "CSS Classes" section, select "no-close" from the list. This is the name of the CSS class you created in the calling report page.

3. To prevent cancel from closing your model page: Add "closeOnEscape:false" to the Attribute property in the Dialog section of the model page's property palette.

Thanks for the help!
   * https://andrewsudworth.wordpress.com/2020/01/27/oracle-apex-remove-the-x-button-from-the-modal-dialog-form/
   * https://www.foxinfotech.org/oracle-apex-disable-escape-key-to-prevent-close-dialog

