_ = require "underscore"
R = require "./R"
Model = require "../Model/Model"
Util = require "../Util/Util"


R.create "AttributeRow",
  propTypes:
    attribute: Model.Attribute

  contextTypes:
    project: Model.Project
    hoverManager: R.HoverManager
    dragManager: R.DragManager

  mixins: [R.AnnotateMixin]

  render: ->
    {attribute} = @props
    {dragManager} = @context

    canDrag = attribute.isVariantOf(Model.Variable)

    drag = dragManager.drag
    isBeingDragged = drag?.type == "attributeRowReorder" and
      drag.consummated and
      drag.attribute == attribute

    attributeRow = R.div {
      className: R.cx {
        AttributeRow: true
        isInherited: !attribute.isNovel()
        isWrapped: @_isWrapped()
        isGoingToChange: @_isGoingToChange()
        canDrag: canDrag
      }
      onMouseDown: @_onMouseDown
      onMouseEnter: @_onMouseEnter
      onMouseLeave: @_onMouseLeave
    },
      R.div {className: "AttributeRowControl"},
        R.div {
          className: R.cx {
            AttributeControl: true
            Interactive: true
            isControllable: @_isControllable()
            isControlled: @_isControlled()
            isImplicitlyControlled: @_isImplicityControlled()
          }
          onClick: @_toggleControl
        }
      R.div {className: "AttributeRowLabel"},
        R.AttributeLabel {attribute}
      R.div {className: "AttributeRowExpression"},
        R.Expression {attribute}
      R.div {
        className: "AttributeRowDragHandle"
        onMouseDown: @_onDragHandleMouseDown
        style:
          visibility: if canDrag and @hovered then "visible" else "hidden"
      },
        "\u2630"

    if isBeingDragged
      R.div {},
        R.div {className: "AttributeRowDragging", style: {
          # left: drag.x
          top: drag.y
          width: drag.width
        }},
          attributeRow
        R.div {className: "AttributeRowPlaceholder", style: {height: drag.height}}
    else
      attributeRow

  _onDragHandleMouseDown: (mouseDownEvent) ->
    target = mouseDownEvent.target
    return if Util.closest(target, ".Interactive")
    mouseDownEvent.preventDefault()
    mouseDownEvent.stopPropagation()
    Util.clearTextFocus()
    @_startDragToReorder(mouseDownEvent)

  _onMouseEnter: ->
    {dragManager} = @context
    return if dragManager.drag?
    @hovered = true

  _onMouseLeave: ->
    {dragManager} = @context
    return if dragManager.drag?
    @hovered = false

  _startDragToReorder: (mouseDownEvent) ->
    {attribute} = @props
    {dragManager} = @context

    el = R.findDOMNode(@)
    rect = el.getBoundingClientRect()

    offsetX = mouseDownEvent.clientX - rect.left
    offsetY = mouseDownEvent.clientY - rect.top

    width = rect.width
    height = rect.height


    console.log("_startDragToReorder", attribute.label)
    dragManager.start mouseDownEvent,
      type: "attributeRowReorder"
      attribute: attribute
      attributeRowEl: el
      outlineEl: Util.closest(el, ".Outline")
      width: width
      height: height
      onMove: (mouseMoveEvent) =>
        dragManager.drag.x = mouseMoveEvent.clientX - offsetX
        dragManager.drag.y = mouseMoveEvent.clientY - offsetY
        dropSpot = @_findDropSpot(dragManager.drag)
        # console.log(dropSpot?.attributesListEl.annotation.element)
        if dropSpot
          @_reorderItem(dropSpot)

  # _findDropSpot returns a dropSpot object consisting of attributesListEl
  # (where to insert) and beforeAttributeRowEl (where to insert after, if null
  # then insert at the end). If nothing is close enough, it will return null.
  _findDropSpot: (drag) ->
    {x, y, attributeRowEl, outlineEl} = drag
    {element} = @props
    dragPosition = [x, y]

    # Temporarily hide AttributeRowPlaceholder for the purpose of this calculation.
    attributeRowPlaceholderEl = attributeRowEl.querySelector(".AttributeRowPlaceholder")
    attributeRowPlaceholderEl?.style.display = "none"

    # Keep track of the best drop spot.
    bestDropSpot = {
      quadrance: 40 * 40 # Threshold to be considered close enough to drop.
    }
    checkFit = (droppedPosition, attributesListEl, beforeAttributeRowEl) =>
      quadrance = Util.quadrance(dragPosition, droppedPosition)
      if quadrance < bestDropSpot.quadrance
        bestDropSpot = {quadrance, attributesListEl, beforeAttributeRowEl}

    # All the places within which we could drop.
    attributesListEls = outlineEl.querySelectorAll(".AttributesList")

    for attributesListEl in attributesListEls
      # Don't try to insert it into itself!
      continue if Util.closest(attributesListEl, ".AttributeRowDragging")

      # Check fit before each existing child.
      childEls = _.filter(attributesListEl.childNodes, (el) -> Util.matches(el, ".AttributeRow.canDrag"))
      for childEl in childEls
        rect = childEl.getBoundingClientRect()
        droppedPosition = [rect.left, rect.top]
        checkFit(droppedPosition, attributesListEl, childEl)

      # Check fit after last draggable AttributeRow.
      if childEls.length > 0
        rect = _.last(childEls).getBoundingClientRect()
        droppedPosition = [rect.left, rect.bottom]
        checkFit(droppedPosition, attributesListEl, null)

      # Check fit at end of the attributes list.
      rect = attributesListEl.getBoundingClientRect()
      droppedPosition = [rect.left, rect.bottom]
      checkFit(droppedPosition, attributesListEl, null)

    # Clean up by unhiding AttributeRowPlaceholderEl
    attributeRowPlaceholderEl?.style.display = ""

    if bestDropSpot.attributesListEl
      return bestDropSpot
    else
      return null

  # _reorderItem will move my element to a dropSpot. dropSpot should be an
  # object with attributesListEl (where to insert) and beforeAttributeRowEl
  # (where to insert after, if null then insert at the end).
  _reorderItem: (dropSpot) ->
    console.log('_reorderItem', dropSpot, dropSpot.beforeAttributeRowEl?.annotation.attribute.label)

    {attribute} = @props
    {attributesListEl, beforeAttributeRowEl} = dropSpot

    console.log('_reorderItem', attribute.label)

    parentElement = attributesListEl.annotation.element
    if beforeAttributeRowEl
      beforeAttribute = beforeAttributeRowEl.annotation.attribute
      if parentElement.children().indexOf(attribute) != -1
        parentElement.removeChild(attribute)
      index = parentElement.children().indexOf(beforeAttribute)
      parentElement.addChild(attribute, index)
    else
      parentElement.addChild(attribute)

  _isWrapped: ->
    {attribute} = @props
    return attribute.exprString.indexOf("\n") != -1

  _isGoingToChange: ->
    {attribute} = @props
    {hoverManager} = @context
    return _.contains(hoverManager.attributesToChange, attribute)

  _selectedElement: ->
    {project} = @context
    return selectedElement = project.selectedParticularElement?.element

  _isControlled: ->
    return _.contains(@context.project.controlledAttributes(), @props.attribute)

  _isImplicityControlled: ->
    return _.contains(@context.project.implicitlyControlledAttributes(), @props.attribute)

  _isControllable: ->
    return _.contains(@context.project.controllableAttributes(), @props.attribute)

  _toggleControl: ->
    {attribute} = @props
    {project} = @context
    selectedElement = project.selectedParticularElement?.element
    return unless selectedElement
    if @_isControlled()
      selectedElement.removeControlledAttribute(attribute)
    else
      selectedElement.addControlledAttribute(attribute)

  annotation: ->
    # Used for drag reording.
    {attribute: @props.attribute}


R.create "AttributeLabel",
  propTypes:
    attribute: Model.Attribute

  contextTypes:
    dragManager: R.DragManager
    hoverManager: R.HoverManager

  mixins: [R.AnnotateMixin]

  render: ->
    {attribute} = @props
    {hoverManager} = @context

    R.div {
      className: R.cx {
        AttributeLabel: true
        Interactive: true
        isHovered: hoverManager.hoveredAttribute == attribute
        isGoingToChange: _.contains(hoverManager.attributesToChange, attribute)
      }
      onMouseDown: @_onMouseDown
      onMouseEnter: @_onMouseEnter
      onMouseLeave: @_onMouseLeave
    },
      R.EditableText {
        className: "EditableTextInline Interactive"
        value: attribute.label
        setValue: (newValue) ->
          attribute.label = newValue
      }

  annotation: ->
    # For autocomplete to find all the attributes on the screen.
    {attribute: @props.attribute}

  _onMouseDown: (mouseDownEvent) ->
    return if Util.closest(mouseDownEvent.target, ".EditableTextInline")

    {attribute} = @props
    {dragManager, hoverManager} = @context
    mouseDownEvent.preventDefault()
    dragManager.start mouseDownEvent,
      type: "transcludeAttribute"
      attribute: attribute
      x: mouseDownEvent.clientX
      y: mouseDownEvent.clientY
      onMove: (mouseMoveEvent) ->
        dragManager.drag.x = mouseMoveEvent.clientX
        dragManager.drag.y = mouseMoveEvent.clientY
      onDrop: ->
        hoverManager.hoveredAttribute = null
      # cursor
      onCancel: =>
        @_transcludeIntoFocusedExpression()

  _transcludeIntoFocusedExpression: ->
    {attribute} = @props
    focusedCodeMirrorEl = document.querySelector(".CodeMirror-focused")
    return unless focusedCodeMirrorEl
    expressionCodeEl = Util.closest(focusedCodeMirrorEl, ".ExpressionCode")
    expressionCode = expressionCodeEl.annotation.component
    expressionCode.transcludeAttribute(attribute)

  _onMouseEnter: (e) ->
    {attribute} = @props
    {dragManager, hoverManager} = @context
    return if dragManager.drag?
    hoverManager.hoveredAttribute = attribute

  _onMouseLeave: (e) ->
    {dragManager, hoverManager} = @context
    return if dragManager.drag?
    hoverManager.hoveredAttribute = null


R.create "AttributeToken",
  propTypes:
    attribute: Model.Attribute
    contextElement: "any" # TODO: should be Model.Element or null

  contextTypes:
    dragManager: R.DragManager
    hoverManager: R.HoverManager

  render: ->
    {attribute} = @props
    {hoverManager} = @context

    R.span {
      className: R.cx {
        ReferenceToken: true
        isHovered: hoverManager.hoveredAttribute == attribute
        isGoingToChange: _.contains(hoverManager.attributesToChange, attribute)
      }
      onMouseEnter: @_onMouseEnter
      onMouseLeave: @_onMouseLeave
    },
      @_label()

  _label: ->
    {attribute, contextElement} = @props
    parentElement = attribute.parentElement()
    if contextElement
      isSameContext = parentElement.isAncestorOf(contextElement)
    else
      isSameContext = false
    if isSameContext
      return attribute.label
    else
      return "#{parentElement.label}’s #{attribute.label}"

  _onMouseEnter: (e) ->
    {attribute} = @props
    {dragManager, hoverManager} = @context
    return if dragManager.drag?
    hoverManager.hoveredAttribute = attribute

  _onMouseLeave: (e) ->
    {dragManager, hoverManager} = @context
    return if dragManager.drag?
    hoverManager.hoveredAttribute = null
