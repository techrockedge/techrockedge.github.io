define [
  'aloha'
  'aloha/plugin'
  'jquery'
  'aloha/ephemera'
  'ui/ui'
  'ui/button'
  'semanticblock/semanticblock-plugin'
  'css!example/css/example-plugin.css'], (Aloha, Plugin, jQuery, Ephemera, UI, Button, semanticBlock) ->

  TYPE_CONTAINER = jQuery '''
      <span class="type-container dropdown aloha-ephemera">
          <span class="type-dropdown btn-link" data-toggle="dropdown"><span class="caret"></span><span class="type"></span></span>
          <ul class="dropdown-menu">
          </ul>
      </span>
  '''

  exampleishClasses = {}
  types = []

  Plugin.create 'example',
    # Default Settings
    # -------
    # The plugin can listen to various classes that should "behave" like an example.
    # For each exampleish element provide a:
    # - `label`: **Required** Shows up in dropdown
    # - `cls` :  **Required** The classname to enable this plugin on
    # - `hasTitle`: **Required** `true` if the element allows optional titles
    # - `type`: value in the `data-label` attribute.
    # - `tagName`: Default: `div`. The HTML element name to use when creating a new example
    # - `titleTagName`: Default: `div`. The HTML element name to use when creating a new title
    #
    # Then, when the user selects "Warning" from the dropdown the element's
    # class and type will be changed and its `> .title` will be removed.
    defaults: [
      # TODO: Allow a plain "example": { typeClass: 'example', hasTitle: true }
      { label: 'Activity', typeClass: 'example', hasTitle: true, dataClass: 'activity' }
      { label: 'Practical', typeClass: 'example', hasTitle: true, dataClass: 'practical' }
      { label: 'Demonstration', typeClass: 'example', hasTitle: true, dataClass: 'demonstration' }
      { label: 'Example', typeClass: 'example', hasTitle: true }
      { label: 'Case in point', typeClass: 'example', hasTitle: true, dataClass: 'case-in-point' }
      { label: 'Case study', typeClass: 'example', hasTitle: true, dataClass: 'case-study' }
      { label: 'Illustration', typeClass: 'example', hasTitle: true, dataClass: 'illustration' }
    ]
    getLabel: ($element) ->
      for type in types
        if $element.is(type.selector)
          return type.label

    activate: ($element) ->
      $title = $element.children('.title')
      $title.attr('hover-placeholder', 'Add a title (optional)')
      $title.aloha()

      label = 'Exercise'

      $body = $element.contents().not($title)

      if types.enableTypes
        jQuery.each types, (i, type) =>
          if $element.is(type.selector)

            label = type.label

            typeContainer = TYPE_CONTAINER.clone()
            # Add dropdown elements for each possible type
            if types.length > 1
              jQuery.each types, (i, dropType) =>
                $option = jQuery('<li><a href="#"></a></li>')
                $option.appendTo(typeContainer.find('.dropdown-menu'))
                $option = $option.children('a')
                $option.text(dropType.label)
                typeContainer.find('.type-dropdown').on 'click', =>
                  jQuery.each types, (i, dropType) =>
                    if $element.attr('data-label') == dropType.dataClass
                      typeContainer.find('.dropdown-menu li').each (i, li) =>
                        jQuery(li).removeClass('checked')
                        if jQuery(li).children('a').text() == dropType.label
                          jQuery(li).addClass('checked')

                $option.on 'click', (e) =>
                  e.preventDefault()
                  # Remove the title if this type does not have one
                  if dropType.hasTitle
                    # If there is no `.title` element then add one in and enable it as an Aloha block
                    if not $element.children('.title')[0]
                      $newTitle = jQuery("<#{dropType.titleTagName or 'span'} class='title'></#{dropType.titleTagName or 'span'}")
                      $element.append($newTitle)
                      $newTitle.aloha()

                  else
                    $element.children('.title').remove()

                  typeContainer.find('.type').text(dropType.label)

                  # Remove the `data-label` if this type does not have one
                  if dropType.dataClass
                    $element.attr('data-label', dropType.dataClass)
                  else
                    $element.removeAttr('data-label')

                  # Remove all notish class names and then add this one in
                  for key of exampleishClasses
                    $element.removeClass key
                  $element.addClass(dropType.typeClass)
            else
              typeContainer.find('.dropdown-menu').remove()
              typeContainer.find('.type').removeAttr('data-toggle')

            typeContainer.find('.type').text(type.label)
            typeContainer.prependTo($element)

      # Create the body and add some placeholder text
      jQuery('<div>')
        .addClass('body')
        .addClass('aloha-block-dropzone')
        .attr('placeholder', "Type the text of your #{label.toLowerCase()} here.")
        .appendTo($element)
        .aloha()
        .append($body)

    deactivate: ($element) ->
      $body = $element.children('.body')
      # The body div could just contain text children.
      # If so, we need to wrap them in a `p` element
      hasTextChildren = $body.children().length != $body.contents().length
      # we also need to poke a `p` in there if its empty
      isEmpty = $body.text().trim() == ''

      if isEmpty
        $body = jQuery('<p class="para"></p>')
      else
        $body = $body.contents()
        $body = $body.wrap('<p></p>').parent() if hasTextChildren

      $element.children('.body').remove()

      # this is kind of awkward. we want to process the title if our current
      # type is configured to have a title, OR if the current type is not
      # recognized we process the title if its there
      hasTitle = undefined
      titleTag = 'span'

      jQuery.each types, (i, type) =>
        if $element.is(type.selector)
          hasTitle = type.hasTitle || false
          titleTag = type.titleTagName || titleTag

      if hasTitle or hasTitle == undefined
        $titleElement = $element.children('.title')
        $title = jQuery("<#{titleTag} class=\"title\"></#{titleTag}>")

        if $titleElement.length
          $title.append($titleElement.contents())
          $titleElement.remove()

        $title.prependTo($element)

      $element.append($body)

    selector: '.example'
    init: () ->
      # Load up specific classes to listen to or use the default
      types = @settings
      jQuery.each types, (i, type) =>
        className = type.typeClass or throw 'BUG Invalid configuration of example plugin. typeClass required!'
        typeName = type.dataClass
        hasTitle = !!type.hasTitle
        label = type.label or throw 'BUG Invalid configuration of example plugin. label required!'

        tagName = type.tagName or 'div'
        titleTagName = type.titleTagName or 'div'

        if typeName
          type.selector = ".#{className}[data-label='#{typeName}']"
        else
          type.selector = ".#{className}:not([data-label])"

        exampleishClasses[className] = true

        newTemplate = jQuery("<#{tagName}></#{tagName}")
        newTemplate.addClass(className)
        newTemplate.attr('data-label', typeName) if typeName
        if hasTitle
          newTemplate.append("<#{titleTagName} class='title'></#{titleTagName}")

        # Add a listener
        UI.adopt "insert-#{className}#{typeName}", Button,
          click: -> semanticBlock.insertAtCursor(newTemplate.clone())

        if 'example' == className and not typeName
          UI.adopt "insertExample", Button,
            click: -> semanticBlock.insertAtCursor(newTemplate.clone())

      semanticBlock.register(this)
