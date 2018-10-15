# To be able to edit math, render in MathJax, and serialize out MathML
# we need to wrap the math element in various elements.
#
# Note: Webkit in linux has a bug where `math` elements are always visible so we wrap it in a hidden `span`
# See http://code.google.com/p/chromium/issues/detail?id=175212

# Example intermediate states:
#
# ### Original DOM
#
#    <math/>

# ### Before MathJax loads (STEP1)
#
#    <span class="math-element aloha-ephemera-wrapper">
#      <span class="mathjax-wrapper aloha-ephemera"> # Note: This element will be removed completely when serialized
#        <math/>
#      </span>
#    </span>

# ### After MathJax loads (STEP2)
#
#    <span class="math-element ...">
#      <span class="mathjax-wrapper ...">
#        <span class="MathJax_Display">...</span>
#        <script type="text/mml">...</script>
#      </span>
#    </span>

# ### After Editor loads (STEP3)
#
#    <span class="math-element ...">
#      <span class="mathjax-wrapper ...">...</span>
#      <span class="mathml-wrapper aloha-ephemera-wrapper">    # This element is to fix the Webkit display bug
#        <math/>
#      </span>
#    </span>


define [ 'aloha', 'aloha/plugin', 'jquery', 'overlay/overlay-plugin', 'ui/ui', 'copy/copy-plugin', 'css!math/css/math.css' ], (Aloha, Plugin, jQuery, Popover, UI, Copy) ->

  EDITOR_HTML = '''
    <div class="math-editor-dialog">
        <div class="math-container">
            <pre><span></span><br></pre>
            <textarea type="text" class="formula" rows="1" autofocus="autofocus"
                      placeholder="Insert your math notation here"></textarea>
        </div>
        <div class="footer controls form-inline">
          <span>This is:</span>
          <label class="radio inline">
              <input type="radio" name="mime-type" value="math/asciimath"> ASCIIMath
          </label>
          <label class="radio inline">
              <input type="radio" name="mime-type" value="math/tex"> LaTeX
          </label>
          <label class="radio inline mime-type-mathml">
              <input type="radio" name="mime-type" value="math/mml"> MathML
          </label>
          <label class="plaintext-label radio inline">
              <input type="radio" name="mime-type" value="text/plain"> Plain text
          </label>
          <button class="btn btn-default clear">Clear</button>
          <button class="btn btn-default copy">Copy</button>
          <button class="btn btn-primary done">Done</button>
        </div>
    </div>
  '''
  # This will be cloned to create a new editor for each popover.
  $_editor = jQuery(EDITOR_HTML)

  LANGUAGES =
    'math/asciimath': {open: '`', close: '`', raw:false}
    'math/tex': {open: '[TEX_START]', close: '[TEX_END]', raw:false}
    'math/mml': {raw: true}
    'text/plain': {raw: true}

  MATHML_ANNOTATION_MIME_ENCODINGS    = [ 'math/tex', 'math/asciimath' ]
  MATHML_ANNOTATION_NONMIME_ENCODINGS =
    'tex':       'math/tex'
    'latex':     'math/tex'
    'asciimath': 'math/asciimath'

  TOOLTIP_TEMPLATE = '<div class="aloha-ephemera tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'

  # Wait until Aloha is started before loading MathJax
  # Also, wrap all math in a span/div. MathJax replaces the MathJax element
  # losing all jQuery data attached to it (like popover data, the original Math Formula, etc)
  # add `aloha-ephemera-wrapper` so this span is unwrapped
  Aloha.ready ->
    MathJax?.Hub.Configured()

  placeCursorAfter = (el) ->
    # The selection-changed stuff in aloha incorrectly thinks we are
    # still inside the math if we attempt to place the cursor JUST after it,
    # so the best thing to do is add a wrapper element which we can focus. By
    # marking this as aloha-ephemera-wrapper, the text inside it is unwrapped
    # when the document is serialised.
    n = el.next()
    if n.is('span.math-element-spaceafter')
      $tail = n
    else
      $tail = jQuery('<span class="math-element-spaceafter aloha-ephemera-wrapper"></span>')
      el.after($tail)

    # This will likely break in IE
    range = document.createRange()
    range.setStart($tail[0], 0)
    range.collapse(true)

    sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)

    # Focus the editable in which el lives
    el.parents('.aloha-editable').first().focus()


  getMathFor = (el) ->
    jax = MathJax?.Hub.getJaxFor(el)
    if jax
      return jQuery(jax.root.toMathML())
    return null

  squirrelMath = ($el) ->
    # `$el` is the `.math-element`

    $mml = getMathFor($el.find('script')[0])
    if $mml != null
      # STEP3
      $el.find('.mathml-wrapper').remove()
      $mml.wrap '<span class="mathml-wrapper aloha-ephemera-wrapper"></span>'
      $el.append $mml.parent()
    else
      console?.warn($el, 'has no associated Jax. Does this happen too often?')

  Aloha.bind 'aloha-editable-created', (evt, editable) ->

    # only process math if it is the editor editable that is being created
    if editable.obj.is(':not(.aloha-root-editable)')
      return

    # Bind copy and paste handlers. When a user copies content with math, place
    # it on the clipboard with a different content type. This will prevent the
    # cleanup that the browser does on namespaces. Use this alternative content
    # type again when pasting. Prevent the browser default. This will only work
    # in browsers that support event.clipboardData, chrome and safari to date.
    editable.obj.on 'copy', (e) ->
      content = e.oerContent or Aloha.getSelection().getRangeAt(0).cloneContents()
      $content = $('<div />').append(content)
      # If there is math among the content we're copying, treat it specially.
      # Check that we also have a script tag in our selection, that occurs
      # towards the end of the math and ensures we have the whole of it.
      # The idea is to only do custom copy/paste if we need it, and let the
      # browser handle other content. Also buffer it in our local copy buffer.
      if $content.has('span.math-element').length and $content.has('script').length
        e.preventDefault()
        clipboard = e.clipboardData or e.originalEvent.clipboardData
        clipboard.setData 'text/oerpub-content', $content.html()
      else
        Copy.buffer $content.html()

    editable.obj.on 'paste', (e) ->
      clipboard = e.clipboardData or e.originalEvent.clipboardData
      content = clipboard.getData('text/oerpub-content')
      if content
        e.preventDefault()
        $content = jQuery(
          '<div class="aloha-ephemera-wrapper newly-pasted-content" />')
          .append(content).hide()

        # Remove ids, new ones will be assigned
        $content.find('*[id]').removeAttr('id')

        # Paste content into editor
        range = Aloha.getSelection().getRangeAt(0)
        range.insertNode($content.get(0))

        # Re-typeset math, because we need our context menu back
        math = []
        $content.find('.math-element').each (idx, el) ->
          deferred = $.Deferred()
          math.push(deferred)
          triggerMathJax jQuery(el), () -> deferred.resolve()

        # When we're done typesetting, show the content and unwrap it.
        $.when.apply($content, math).done ->
          $content.each () ->
            $$$ = jQuery(@)
            $$$.replaceWith $$$.contents()

    # Bind ctrl+m to math insert/mathify
    editable.obj.bind 'keydown', 'ctrl+m', (evt) ->
      insertMath()
      evt.preventDefault()

    # STEP1
    $maths = editable.obj.find('math')
    $maths.wrap '<span class="math-element aloha-ephemera-wrapper" contenteditable="false"><span class="mathjax-wrapper aloha-ephemera"></span></span>'

    # TODO: Explicitly call Mathjax Typeset
    jQuery.each $maths, (i, mml) ->
      $mml = jQuery(mml)
      $mathElement = $mml.parent().parent()

      $mml.clone().wrap('<span class="mathml-wrapper aloha-ephemera-wrapper"></span>').parent().appendTo($mathElement)
      # replace the MathML with ASCII/LaTeX formula if possible
      mathParts = findFormula $mml
      if mathParts.mimeType in MATHML_ANNOTATION_MIME_ENCODINGS
        $mathElement.find('.mathjax-wrapper').text(LANGUAGES[mathParts.mimeType].open +
                                                   mathParts.formula +
                                                   LANGUAGES[mathParts.mimeType].close)
      triggerMathJax $mathElement, ->
        if mathParts.mimeType in MATHML_ANNOTATION_MIME_ENCODINGS
          addAnnotation $mathElement, mathParts.formula, mathParts.mimeType
        makeCloseIcon $mathElement

    # What to when user clicks on math
    jQuery(editable.obj).on 'click.matheditor', '.math-element, .math-element *', (evt) ->
      $el = jQuery(@)

      $el = $el.parents('.math-element') if not $el.is('.math-element')

      # Make sure the math element is never editable
      $el.contentEditable(false)

      # Update what Aloha thinks is the selection
      # Can't just use Aloha.Selection.updateSelection because the thing that was clicked isn't editable
      # and setSelection will just silently return without triggering the selection update.
      range = new GENTICS.Utils.RangeObject()
      range.startContainer = range.endContainer = $el[0]
      range.startOffset = range.endOffset = 0
      Aloha.Selection.rangeObject = range

      #evt.target = evt.currentTarget = $el[0]
      Aloha.trigger('aloha-selection-changed', [range, evt])

      # Since the click is on the math-element or its children
      # (the math element is just a little horizontal bar but its children
      # stick out above and below it). Don't handle the same event for each
      # child.
      evt.stopPropagation()

    editable.obj.on('click.matheditor', '.math-element-destroy', (e) ->
      jQuery(e.target).tooltip('destroy')
      $el = jQuery(e.target).closest('.math-element')
      # Though the tooltip was bound to the editor and delegates
      # to these items, you still have to clean it up youself
      $el.siblings('.math-element-spaceafter').remove()
      $el.popover('hide').tooltip('destroy').remove()
      Aloha.activeEditable.smartContentChange {type: 'block-change'}
    )

    # Add hlpful tooltips
    if jQuery.ui and jQuery.ui.tooltip
      # Use jq.ui tooltip
      editable.obj.tooltip(
        items: ".math-element",
        content: -> 'Click anywhere in math to edit it',
        template: TOOLTIP_TEMPLATE)
    else
      # This requires a custom version of jquery-ui, to avoid the conflict
      # between the two .toolbar plugins. This one assumes bootstrap
      # tooltip
      editable.obj.tooltip(
        selector: '.math-element'
        placement: 'top'
        title: 'Click anywhere in math to edit it'
        trigger: 'hover',
        template: TOOLTIP_TEMPLATE)

  insertMathInto = ($container) ->
    $math = jQuery('<span class="math-element aloha-ephemera-wrapper"><span class="mathjax-wrapper aloha-ephemera"></span></span>')
    $container.html($math)
    $math.trigger 'show-popover'

  insertMath = () ->
    $el = jQuery('<span class="math-element aloha-ephemera-wrapper"><span class="mathjax-wrapper aloha-ephemera">&#160;</span></span>') # nbsp
    range = Aloha.Selection.getRangeObject()
    if range.isCollapsed()
      GENTICS.Utils.Dom.insertIntoDOM $el, range, Aloha.activeEditable.obj
      # Callback opens up the math editor by "clicking" on it
      $el.trigger 'show-popover'
      makeCloseIcon($el)
    else
      # Assume the user highlighted ASCIIMath (by putting the text in backticks)
      formula = range.getText()
      $el.find('.mathjax-wrapper').text(LANGUAGES['math/tex'].open +
                                        formula +
                                        LANGUAGES['math/tex'].close)
      GENTICS.Utils.Dom.removeRange range
      GENTICS.Utils.Dom.insertIntoDOM $el, range, Aloha.activeEditable.obj
      triggerMathJax $el, ->
        addAnnotation $el, formula, 'math/tex'
        makeCloseIcon($el)
        Aloha.Selection.preventSelectionChanged()
        placeCursorAfter($el)
        Aloha.activeEditable.smartContentChange {type: 'block-change'}

  # STEP2
  triggerMathJax = ($mathElement, cb) ->
    if MathJax?
      # keep the `.math-element` parent
      # Be sure to squirrel away the MathML because the DOM only contains the HTML+CSS output
      callback = () ->
        squirrelMath $mathElement
        cb?()
      MathJax.Hub.Queue ["Typeset", MathJax.Hub, $mathElement.find('.mathjax-wrapper')[0], callback]
    else
      console and console.log 'MathJax was not loaded properly'

  cleanupFormula = ($editor, $span, destroy=false) ->
    # If math is empty, remove the box
    if destroy or jQuery.trim($editor.find('.formula').val()).length == 0
      $span.find('.math-element-destroy').tooltip('destroy')
      $span.siblings('.math-element-spaceafter').remove()
      $span.remove()

  # $span contains the span with LaTeX/ASCIIMath
  buildEditor = ($span) ->
    $editor = $_editor.clone(true)
    $formula = $editor.find('.formula')

    # If this is new math, drop the plain text option.
    if $span.find('.mathjax-wrapper > *').length is 0
      $editor.find('.plaintext-label').remove()

    # Bind some actions for the buttons
    $editor.find('.done').on 'click', ->
      $span.popover('hide')
      placeCursorAfter($span)
    $editor.find('.remove').on 'click', ->
      $span.popover('hide')
      cleanupFormula($editor, $span, true)
    $editor.find('.copy').on 'click', ->
      Copy.buffer $span.outerHtml(), 'text/oerpub-content'
    $editor.find('.clear').on 'click', ->
      $formula.val('')
      $formula.trigger('input')

    # Set the formula in jQuery data if it hasn't been set before
    #$span.data('math-formula', $span.data('math-formula') or $span.attr('data-math-formula') or $span.text())

    mimeType = $span.find('script[type]').attr('type') or 'math/tex'
    # tex could be "math/tex; mode=display" so split in the semicolon
    mimeType = mimeType.split(';')[0]

    formula = $span.find('script[type]').html()

    # Set the language and fill in the formula
    $editor.find("input[name=mime-type][value='#{mimeType}']").prop('checked', true)
    $formula.val(formula)

    # Set the hidden pre that causes auto-sizing to the same value
    $editor.find('.math-container pre span').text(formula)

    # If the language isn't MathML then hide the MathML radio
    $editor.find("label.mime-type-mathml").remove() if mimeType != 'math/mml'

    keyTimeout = null
    keyDelay = () ->
      formula = jQuery(@).val()
      type = $editor.find('input[name=mime-type]:checked').val()

      $mathPoint = $span.children('.mathjax-wrapper').eq(0)
      if not $mathPoint.length
        $mathPoint = jQuery('<span class="mathjax-wrapper aloha-ephemera"></span>')
        $span.prepend $mathPoint

      if type == 'text/plain'
        # Temporarily squirel away the math formula in a script tag with the
        # relevant mime type. If the user changes his mind at this point and
        # selects a different mimetype, everything works as expected. Once
        # the user closes the popover we will unmathify and clean this up if
        # plain text is still selected.
        jQuery('<script type="text/plain"></script>').text(
            formula).appendTo($span)
        $mathPoint.text(formula)
      else
        # Clean up any <script> tags that might have been added for plain text,
        # which happens if you switch away from plain text.
        $span.find('script[type="text/plain"]').remove()
        if LANGUAGES[type].raw
          $formula = jQuery(formula)
          $mathPoint.text('').append($formula)
        else
          formulaWrapped = LANGUAGES[type].open + formula + LANGUAGES[type].close
          $mathPoint.text(formulaWrapped)
        triggerMathJax $span, ->
          # Save the Edited text into the math annotation element
          $mathml = $span.find('math')
          if $mathml[0]
            if type in MATHML_ANNOTATION_MIME_ENCODINGS
              addAnnotation $span, formula, type
            makeCloseIcon($span)
          Aloha.activeEditable.smartContentChange {type: 'block-change'}

      # TODO: Async save the input when MathJax correctly parses and typesets the text
      $span.data('math-formula', formula)
      $formula.trigger('focus')

    $formula.on 'input', () ->
      clearTimeout(keyTimeout)
      setTimeout(keyDelay.bind(@), 500)
      $editor.find('.math-container pre span').text($formula.val())

    radios = $editor.find('input[name=mime-type]')
    radios.on 'click', () ->
      # The following lines are for bootstrap 2
      # radios.prop('checked', false)
      # jQuery(@).prop('checked', true)

      clearTimeout(keyTimeout)
      setTimeout(keyDelay.bind($formula), 500)

    $span.off('shown.math').on 'shown.math', () ->
      $span.css 'background-color', '#E5EEF5'
      $el = jQuery(@)
      tt = $el.data('tooltip')
      tt.hide().disable() if tt
      setTimeout( () ->
        $popover = $el.data('popover')
        $popover.$tip.find('.formula').trigger('focus') if $popover
      , 10)

    $span.off('hidden.math').on 'hidden.math', () ->
      $span.css 'background-color', ''
      tt = jQuery(@).data('tooltip')
      tt.enable() if tt
      cleanupFormula($editor, jQuery(@))

      # If the user changed the content to plain text, then drop the wrappers
      if $span.find('script[type="text/plain"]').length
        $span.replaceWith(
            $span.find('.mathjax-wrapper').html())

    $editor

  makeCloseIcon = ($el) ->
    # $el is <span class="math-element">
    $closer = $el.find '.math-element-destroy'
    if not $closer[0]?
      $closer = jQuery('<span class="math-element-destroy aloha-ephemera fa fa-times" title="Delete\u00A0math"></span>')
      # The hidden event on the closeIcon should not propagate, otherwise it
      # triggers cleanupFormula repeatedly on an empty math element, causing
      # infinite recursion.
      $closer.on 'hidden', (e) -> e.stopPropagation()

      if jQuery.ui and jQuery.ui.tooltip
        $closer.tooltip()
      else
        $closer.tooltip(placement: 'bottom', template: TOOLTIP_TEMPLATE)
      $el.append($closer)

  addAnnotation = ($span, formula, mimeType) ->
      # $span is <span class="math-element">
    $mml = $span.find('math')
    if $mml[0]
      $annotation = $mml.find('annotation')
      # ## Finicky MathML structure
      #
      # The generated MathML needs:
      #
      # - A single `<semantics/>` element
      # - The semantics element **must** have _exactly_ 2 children
      # - The second child **must** be the `<annotation/>`

      # If the `<annotation/>` element is not the 2nd child or not in a `<semantics/>`
      # then MathJax will treat it as a '<mtext/>' and not hide it.
      if not $annotation[0]?
        if $mml.children().length > 1 # Wrap math equation in mrow if equation is more than one single child
          $mml.wrapInner('<mrow></mrow>')
        $semantics = $mml.find('semantics')
        if not $semantics[0]
          $mml.wrapInner('<semantics></semantics>')
          $semantics = $mml.find('semantics')
        $annotation = jQuery('<annotation></annotation>').appendTo($semantics)
      $annotation.attr('encoding', mimeType)
      $annotation.text(formula)

  getEncoding = ($annotation) ->
    encoding = $annotation.attr 'encoding'
    #if MATHML_ANNOTATION_MIME_ENCODINGS.contains encoding
    if encoding in MATHML_ANNOTATION_MIME_ENCODINGS
      mimeEncoding = encoding
      return mimeEncoding
    # cannonicalize the non-mime encodings
    encoding = encoding.toLowerCase()
    if encoding of MATHML_ANNOTATION_NONMIME_ENCODINGS
      mimeEncoding = MATHML_ANNOTATION_NONMIME_ENCODINGS[encoding]
      return mimeEncoding
    return null

  # Looking to precisely match the math we create in the editor
  #    <math>
  #      <semantics>
  #        single math element
  #        <annotation />
  #      </semantics>
  #    </math>
  findFormula = ($mml) ->
    formula = null
    mimeType = "math/mml"
    if $mml.children().length is 1
      $firstChild = jQuery($mml.children()[0])
      if $firstChild.is 'semantics'
        $semantics = $firstChild
        if $semantics.children().length is 2
          $secondChild = jQuery($semantics.children()[1])
          if $secondChild.is 'annotation[encoding]'
            $annotation = $secondChild
            encoding = getEncoding $annotation
            formula = $annotation.text()
            if encoding of LANGUAGES
              return { 'mimeType': encoding, 'formula': formula }
    return { 'mimeType': mimeType, 'formula': formula }

  # Register the button with an action
  UI.adopt 'insertMath', null,
    click: () -> insertMath()

  # Add a copy option to the mathjax menu
  MathJax?.Callback.Queue MathJax.Hub.Register.StartupHook('MathMenu Ready'), () ->
    copyCommand = MathJax.Menu.ITEM.COMMAND 'Copy Math', (e,f,g) ->
      $script = jQuery(document.getElementById(MathJax.Menu.jax.inputID))
      Copy.buffer $script.parent().parent().outerHtml(), 'text/oerpub-content'
    MathJax.Menu.menu.items.unshift copyCommand

  ob =
    selector: '.math-element'
    populator: buildEditor
    insertMathInto: insertMathInto
    insertMath: insertMath
    placement: 'top'
    markerclass: 'math-popover'
    # Expose editor, so the cheatsheet plugin can modify it.
    editor: $_editor

  Popover.register(ob)
  return ob
