$ = jQuery
$.fn.disableClientSideValidations = ->
  ClientSideValidations.disable this
  this

$.fn.enableClientSideValidations = ->
  @filter(ClientSideValidations.selectors.forms).each ->
    ClientSideValidations.enablers.form this

  @filter(ClientSideValidations.selectors.inputs).each ->
    ClientSideValidations.enablers.input this

  this

$.fn.resetClientSideValidations = ->
  @filter(ClientSideValidations.selectors.forms).each ->
    ClientSideValidations.reset this

  this

$.fn.validate = ->
  @filter(ClientSideValidations.selectors.forms).each ->
    $(this).enableClientSideValidations()

  this

$.fn.isValid = (validators) ->
  obj = $(this[0])
  if obj.is("form")
    validateForm obj, validators
  else
    validateElement obj, validatorsFor(this[0].name, validators)

validatorsFor = (name, validators) ->
  if captures = name.match(/\[(\w+_attributes)\].*\[(\w+)\]$/)
    for validator_name of validators
      validator = validators[validator_name]
      name = name.replace(/\[[\da-z_]+\]\[(\w+)\]$/g, "[][$1]")  if validator_name.match("\\[" + captures[1] + "\\].*\\[\\]\\[" + captures[2] + "\\]$")
  validators[name] or {}

validateForm = (form, validators) ->
  form.trigger "form:validate:before.ClientSideValidations"
  valid = true
  form.find(ClientSideValidations.selectors.validate_inputs).each ->
    valid = false  unless $(this).isValid(validators)
    true

  if valid
    form.trigger "form:validate:pass.ClientSideValidations"
  else
    form.trigger "form:validate:fail.ClientSideValidations"
  form.trigger "form:validate:after.ClientSideValidations"
  valid

validateElement = (element, validators) ->
  element.trigger "element:validate:before.ClientSideValidations"
  passElement = ->
    element.trigger("element:validate:pass.ClientSideValidations").data "valid", null

  failElement = (message) ->
    element.trigger("element:validate:fail.ClientSideValidations", message).data "valid", false
    false

  afterValidate = ->
    element.trigger("element:validate:after.ClientSideValidations").data("valid") isnt false

  executeValidators = (context) ->
    for kind of context
      fn = context[kind]
      if validators[kind]
        _ref = validators[kind]
        _i = 0
        _len = _ref.length

        while _i < _len
          validator = _ref[_i]
          if message = fn.call(context, element, validator)
            valid = failElement(message)
            break
          _i++
        break  unless valid
    valid

  destroyInputName = element.attr("name").replace(/\[([^\]]*?)\]$/, "[_destroy]")
  if $("input[name='" + destroyInputName + "']").val() is "1"
    passElement()
    return afterValidate()
  return afterValidate()  if element.data("changed") is false
  element.data "changed", false
  local = ClientSideValidations.validators.local
  remote = ClientSideValidations.validators.remote
  passElement()  if executeValidators(local) and executeValidators(remote)
  afterValidate()

window.ClientSideValidations = {}  if window.ClientSideValidations
window.ClientSideValidations.forms = {}  if window.ClientSideValidations.forms
window.ClientSideValidations.selectors =
  inputs: ":input:not(button):not([type=\"submit\"])[name]"
  validate_inputs: ":input:enabled:visible[data-validate]"
  forms: "form[data-validate]"

window.ClientSideValidations.reset = (form) ->

  $form = $(form)
  ClientSideValidations.disable form
  for key of form.ClientSideValidations.settings.validators
    form.ClientSideValidations.removeError $form.find("[name='" + key + "']")
  ClientSideValidations.enablers.form form

window.ClientSideValidations.disable = (target) ->

  $target = $(target)
  $target.off ".ClientSideValidations"
  if $target.is("form")
    ClientSideValidations.disable $target.find(":input")
  else
    $target.removeData "valid"
    $target.removeData "changed"
    $target.filter(":input").each ->
      $(this).removeAttr "data-validate"


window.ClientSideValidations.enablers =
  form: (form) ->
    $form = $(form)
    form.ClientSideValidations =
      settings: window.ClientSideValidations.forms[$form.attr("id")]
      addError: (element, message) ->
        ClientSideValidations.formBuilders[form.ClientSideValidations.settings.type].add element, form.ClientSideValidations.settings, message

      removeError: (element) ->
        ClientSideValidations.formBuilders[form.ClientSideValidations.settings.type].remove element, form.ClientSideValidations.settings

    _ref =
      "submit.ClientSideValidations": (eventData) ->
        unless $form.isValid(form.ClientSideValidations.settings.validators)
          eventData.preventDefault()
          eventData.stopImmediatePropagation()

      "ajax:beforeSend.ClientSideValidations": (eventData) ->
        $form.isValid form.ClientSideValidations.settings.validators  if eventData.target is this

      "form:validate:after.ClientSideValidations": (eventData) ->
        ClientSideValidations.callbacks.form.after $form, eventData

      "form:validate:before.ClientSideValidations": (eventData) ->
        ClientSideValidations.callbacks.form.before $form, eventData

      "form:validate:fail.ClientSideValidations": (eventData) ->
        ClientSideValidations.callbacks.form.fail $form, eventData

      "form:validate:pass.ClientSideValidations": (eventData) ->
        ClientSideValidations.callbacks.form.pass $form, eventData

    for event of _ref
      binding = _ref[event]
      $form.on event, binding
    $form.find(ClientSideValidations.selectors.inputs).each ->
      ClientSideValidations.enablers.input this


  input: (input) ->
    $input = $(input)
    form = input.form
    $form = $(form)
    _ref =
      "focusout.ClientSideValidations": ->
        $(this).isValid form.ClientSideValidations.settings.validators

      "change.ClientSideValidations": ->
        $(this).data "changed", true

      "element:validate:after.ClientSideValidations": (eventData) ->
        ClientSideValidations.callbacks.element.after $(this), eventData

      "element:validate:before.ClientSideValidations": (eventData) ->
        ClientSideValidations.callbacks.element.before $(this), eventData

      "element:validate:fail.ClientSideValidations": (eventData, message) ->
        element = $(this)
        ClientSideValidations.callbacks.element.fail element, message, (->
          form.ClientSideValidations.addError element, message
        ), eventData

      "element:validate:pass.ClientSideValidations": (eventData) ->
        element = $(this)
        ClientSideValidations.callbacks.element.pass element, (->
          form.ClientSideValidations.removeError element
        ), eventData

    for event of _ref
      binding = _ref[event]
      $input.filter(":not(:radio):not([id$=_confirmation])").each(->
        $(this).attr "data-validate", true
      ).on event, binding
    $input.filter(":checkbox").on "click.ClientSideValidations", ->
      $(this).isValid form.ClientSideValidations.settings.validators
      true

    $input.filter("[id$=_confirmation]").each ->
      confirmationElement = $(this)
      element = $form.find("#" + (@id.match(/(.+)_confirmation/)[1]) + ":input")
      if element[0]
        _ref1 =
          "focusout.ClientSideValidations": ->
            element.data("changed", true).isValid form.ClientSideValidations.settings.validators

          "keyup.ClientSideValidations": ->
            element.data("changed", true).isValid form.ClientSideValidations.settings.validators

        _results = []
        for event of _ref1
          binding = _ref1[event]
          _results.push $("#" + (confirmationElement.attr("id"))).on(event, binding)
        _results


window.ClientSideValidations.validators =
  all: ->
    jQuery.extend {}, ClientSideValidations.validators.local, ClientSideValidations.validators.remote

  local:
    presence: (element, options) ->
      options.message  if /^\s*$/.test(element.val() or "")

    acceptance: (element, options) ->
      switch element.attr("type")
        when "checkbox"
          return options.message  unless element.prop("checked")
        when "text"
          options.message  if element.val() isnt (((if (_ref = options.accept)? then _ref.toString() else undefined)) or "1")

    format: (element, options) ->
      message = @presence(element, options)
      if message
        return  if options.allow_blank is true
        return message
      return options.message  if options["with"] and not options["with"].test(element.val())
      options.message  if options.without and options.without.test(element.val())

    numericality: (element, options) ->
      val = jQuery.trim(element.val())
      unless ClientSideValidations.patterns.numericality.test(val)
        return  if options.allow_blank is true and @presence(element,
          message: options.messages.numericality
        )
        return options.messages.numericality
      val = val.replace(new RegExp("\\" + ClientSideValidations.number_format.delimiter, "g"), "").replace(new RegExp("\\" + ClientSideValidations.number_format.separator, "g"), ".")
      return options.messages.only_integer  if options.only_integer and not /^[+-]?\d+$/.test(val)
      CHECKS =
        greater_than: ">"
        greater_than_or_equal_to: ">="
        equal_to: "=="
        less_than: "<"
        less_than_or_equal_to: "<="

      form = $(element[0].form)
      for check of CHECKS
        operator = CHECKS[check]
        continue  unless options[check]?
        if not isNaN(parseFloat(options[check])) and isFinite(options[check])
          check_value = options[check]
        else if form.find("[name*=" + options[check] + "]").size() is 1
          check_value = form.find("[name*=" + options[check] + "]").val()
        else
          return
        fn = new Function("return " + val + " " + operator + " " + check_value)
        return options.messages[check]  unless fn()
      return options.messages.odd  if options.odd and not (parseInt(val, 10) % 2)
      options.messages.even  if options.even and (parseInt(val, 10) % 2)

    length: (element, options) ->
      tokenizer = options.js_tokenizer or "split('')"
      tokenized_length = new Function("element", "return (element.val()." + tokenizer + " || '').length")(element)
      CHECKS =
        is: "=="
        minimum: ">="
        maximum: "<="

      blankOptions = {}
      blankOptions.message = (if options.is then options.messages.is else (if options.minimum then options.messages.minimum else undefined))
      message = @presence(element, blankOptions)
      if message
        return  if options.allow_blank is true
        return message
      for check of CHECKS
        operator = CHECKS[check]
        continue  unless options[check]
        fn = new Function("return " + tokenized_length + " " + operator + " " + options[check])
        return options.messages[check]  unless fn()
      return

    exclusion: (element, options) ->
      message = @presence(element, options)
      if message
        return  if options.allow_blank is true
        return message
      if options["in"]
        return options.message  if _ref = element.val()
        __indexOf_.call((->
          _ref1 = options["in"]
          _results = []
          _i = 0
          _len = _ref1.length

          while _i < _len
            option = _ref1[_i]
            _results.push option.toString()
            _i++
          _results
        )(), _ref) >= 0
      if options.range
        lower = options.range[0]
        upper = options.range[1]
        options.message  if element.val() >= lower and element.val() <= upper

    inclusion: (element, options) ->
      message = @presence(element, options)
      if message
        return  if options.allow_blank is true
        return message
      if options["in"]
        return  if _ref = element.val()
        __indexOf_.call((->
          _ref1 = options["in"]
          _results = []
          _i = 0
          _len = _ref1.length

          while _i < _len
            option = _ref1[_i]
            _results.push option.toString()
            _i++
          _results
        )(), _ref) >= 0

        return options.message
      if options.range
        lower = options.range[0]
        upper = options.range[1]
        return  if element.val() >= lower and element.val() <= upper
        options.message

    confirmation: (element, options) ->
      options.message  if element.val() isnt jQuery("#" + (element.attr("id")) + "_confirmation").val()

    uniqueness: (element, options) ->
      name = element.attr("name")
      if /_attributes\]\[\d/.test(name)
        matches = name.match(/^(.+_attributes\])\[\d+\](.+)$/)
        name_prefix = matches[1]
        name_suffix = matches[2]
        value = element.val()
        if name_prefix and name_suffix
          form = element.closest("form")
          valid = true
          form.find(":input[name^=\"" + name_prefix + "\"][name$=\"" + name_suffix + "\"]").each ->
            if $(this).attr("name") isnt name
              if $(this).val() is value
                valid = false
                $(this).data "notLocallyUnique", true
              else
                $(this).removeData("notLocallyUnique").data "changed", true  if $(this).data("notLocallyUnique")

          options.message  unless valid

  remote:
    uniqueness: (element, options) ->
      message = ClientSideValidations.validators.local.presence(element, options)
      if message
        return  if options.allow_blank is true
        return message
      data = {}
      data.case_sensitive = !!options.case_sensitive
      data.id = options.id  if options.id
      if options.scope
        data.scope = {}
        _ref = options.scope
        for key of _ref
          scope_value = _ref[key]
          scoped_name = element.attr("name").replace(/\[\w+\]$/, "[" + key + "]")
          scoped_element = jQuery("[name='" + scoped_name + "']")
          jQuery("[name='" + scoped_name + "']:checkbox").each ->
            scoped_element = this  if @checked

          if scoped_element[0] and scoped_element.val() isnt scope_value
            data.scope[key] = scoped_element.val()
            scoped_element.unbind("change." + element.id).bind "change." + element.id, ->
              element.trigger "change.ClientSideValidations"
              element.trigger "focusout.ClientSideValidations"

          else
            data.scope[key] = scope_value
      if /_attributes\]/.test(element.attr("name"))
        name = element.attr("name").match(/\[\w+_attributes\]/g).pop().match(/\[(\w+)_attributes\]/).pop()
        name += /(\[\w+\])$/.exec(element.attr("name"))[1]
      else
        name = element.attr("name")
      name = options["class"] + "[" + name.split("[")[1]  if options["class"]
      data[name] = element.val()
      jQuery.ajax
        url: ClientSideValidations.remote_validators_url_for("uniqueness")
        data: data
        async: false
        cache: false
        success: (data) ->
          msg = options.message  unless data
          return

      msg

window.ClientSideValidations.remote_validators_url_for = (validator) ->
  unless ClientSideValidations.remote_validators_prefix is ""
    "//" + window.location.host + "/" + ClientSideValidations.remote_validators_prefix + "/validators/" + validator
  else
    "//" + window.location.host + "/validators/" + validator

window.ClientSideValidations.disableValidators = ->
  return  if window.ClientSideValidations.disabled_validators is undefined
  _ref = window.ClientSideValidations.validators.remote
  _results = []
  for validator of _ref
    func = _ref[validator]
    if __indexOf_.call(window.ClientSideValidations.disabled_validators, validator) >= 0
      _results.push delete window.ClientSideValidations.validators.remote[validator]

    else
      _results.push undefined
  _results

window.ClientSideValidations.formBuilders = "ActionView::Helpers::FormBuilder":
  add: (element, settings, message) ->
    form = $(element[0].form)
    if element.data("valid") isnt false and (not (form.find("label.message[for='" + (element.attr("id")) + "']")[0]?))
      inputErrorField = jQuery(settings.input_tag)
      labelErrorField = jQuery(settings.label_tag)
      label = form.find("label[for='" + (element.attr("id")) + "']:not(.message)")
      element.attr "autofocus", false  if element.attr("autofocus")
      element.before inputErrorField
      inputErrorField.find("span#input_tag").replaceWith element
      inputErrorField.find("label.message").attr "for", element.attr("id")
      labelErrorField.find("label.message").attr "for", element.attr("id")
      labelErrorField.insertAfter label
      labelErrorField.find("label#label_tag").replaceWith label
    form.find("label.message[for='" + (element.attr("id")) + "']").text message

  remove: (element, settings) ->
    form = $(element[0].form)
    errorFieldClass = jQuery(settings.input_tag).attr("class")
    inputErrorField = element.closest("." + (errorFieldClass.replace(" ", ".")))
    label = form.find("label[for='" + (element.attr("id")) + "']:not(.message)")
    labelErrorField = label.closest("." + errorFieldClass)
    if inputErrorField[0]
      inputErrorField.find("#" + (element.attr("id"))).detach()
      inputErrorField.replaceWith element
      label.detach()
      labelErrorField.replaceWith label

window.ClientSideValidations.patterns = numericality: /^(-|\+)?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d*)?$/
window.ClientSideValidations.callbacks =
  element:
    after: (element, eventData) ->

    before: (element, eventData) ->

    fail: (element, message, addError, eventData) ->
      addError()

    pass: (element, removeError, eventData) ->
      removeError()

  form:
    after: (form, eventData) ->

    before: (form, eventData) ->

    fail: (form, eventData) ->

    pass: (form, eventData) ->

$ ->
  ClientSideValidations.disableValidators()
  $(ClientSideValidations.selectors.forms).validate()
