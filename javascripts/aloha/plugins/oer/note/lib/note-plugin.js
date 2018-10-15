// Generated by CoffeeScript 1.8.0
(function() {
  define(['aloha', 'aloha/plugin', 'jquery', 'aloha/ephemera', 'ui/ui', 'ui/button', 'semanticblock/semanticblock-plugin', 'css!note/css/note-plugin.css'], function(Aloha, Plugin, jQuery, Ephemera, UI, Button, semanticBlock) {
    var TYPE_CONTAINER, notishClasses, types;
    TYPE_CONTAINER = jQuery('<span class="type-container dropdown aloha-ephemera">\n    <span class="type-dropdown btn-link" data-toggle="dropdown"><span class="caret"></span><span class="type"></span></span>\n    <ul class="dropdown-menu">\n    </ul>\n</span>');
    notishClasses = {};
    types = [];
    return Plugin.create('note', {
      defaults: [
        {
          label: 'Note2',
          typeClass: 'note',
          dataClass: 'note2',
          hasTitle: true
        }, {
          label: 'Note',
          typeClass: 'note',
          hasTitle: true
        }
      ],
      getLabel: function($element) {
        var type, _i, _len;
        for (_i = 0, _len = types.length; _i < _len; _i++) {
          type = types[_i];
          if ($element.is(type.selector)) {
            return type.label;
          }
        }
      },
      activate: function($element) {
        var $body, $title, label;
        $element.attr('data-format-whitelist', '["p"]');
        Ephemera.markAttr($element, 'data-format-whitelist');
        $title = $element.children('.title');
        $title.attr('hover-placeholder', 'Add a title (optional)');
        $title.aloha();
        label = 'Note';
        $body = $element.contents().not($title);
        jQuery.each(types, (function(_this) {
          return function(i, type) {
            var typeContainer;
            if ($element.is(type.selector)) {
              label = type.label;
              typeContainer = TYPE_CONTAINER.clone();
              if (types.length > 1) {
                jQuery.each(types, function(i, dropType) {
                  var $option;
                  $option = jQuery('<li><span class="btn-link"></span></li>');
                  $option.appendTo(typeContainer.find('.dropdown-menu'));
                  $option = $option.children('span');
                  $option.text(dropType.label);
                  typeContainer.find('.type-dropdown').on('click', function() {
                    return jQuery.each(types, function(i, dropType) {
                      if ($element.attr('data-label') === dropType.dataClass) {
                        return typeContainer.find('.dropdown-menu li').each(function(i, li) {
                          jQuery(li).removeClass('checked');
                          if (jQuery(li).children('span').text() === dropType.label) {
                            return jQuery(li).addClass('checked');
                          }
                        });
                      }
                    });
                  });
                  Aloha.trigger('aloha-smart-content-changed', {
                    'triggerType': 'block-change'
                  });
                  return $option.on('click', function() {
                    var $newTitle, key;
                    if (dropType.hasTitle) {
                      if (!$element.children('.title')[0]) {
                        $newTitle = jQuery("<" + (dropType.titleTagName || 'span') + " class='title'></" + (dropType.titleTagName || 'span'));
                        $element.append($newTitle);
                        $newTitle.aloha();
                      }
                    } else {
                      $element.children('.title').remove();
                    }
                    if (dropType.dataClass) {
                      $element.attr('data-label', dropType.dataClass);
                    } else {
                      $element.removeAttr('data-label');
                    }
                    typeContainer.find('.type').text(dropType.label);
                    for (key in notishClasses) {
                      $element.removeClass(key);
                    }
                    return $element.addClass(dropType.typeClass);
                  });
                });
              } else {
                typeContainer.find('.dropdown-menu').remove();
                typeContainer.find('.type').removeAttr('data-toggle');
              }
              typeContainer.find('.type').text(type.label);
              return typeContainer.prependTo($element);
            }
          };
        })(this));
        return $body = jQuery('<div>').addClass('body').addClass('aloha-block-dropzone').attr('placeholder', "Type the text of your " + (label.toLowerCase()) + " here.").appendTo($element).aloha().append($body);
      },
      deactivate: function($element) {
        var $body, $title, $titleElement, element, hasTitle, titleTag, _i, _len, _ref;
        $body = $element.children('.body');
        _ref = $body.contents();
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          element = _ref[_i];
          if (element.nodeName === '#text') {
            if (element.data.trim().length) {
              jQuery(element).wrap('<p></p>');
            } else {
              element.remove();
            }
          }
        }
        $body = $body.contents();
        $element.children('.body').remove();
        hasTitle = void 0;
        titleTag = 'span';
        jQuery.each(types, (function(_this) {
          return function(i, type) {
            if ($element.is(type.selector)) {
              hasTitle = type.hasTitle || false;
              return titleTag = type.titleTagName || titleTag;
            }
          };
        })(this));
        if (hasTitle || hasTitle === void 0) {
          $titleElement = $element.children('.title');
          $title = jQuery("<" + titleTag + " class=\"title\"></" + titleTag + ">");
          if ($titleElement.length) {
            $title.append($titleElement.contents());
            $titleElement.remove();
          }
          $title.prependTo($element);
        }
        return $element.append($body);
      },
      selector: '.note',
      init: function() {
        types = this.settings;
        jQuery.each(types, (function(_this) {
          return function(i, type) {
            var className, hasTitle, label, newTemplate, tagName, titleTagName, typeName;
            className = type.typeClass || (function() {
              throw 'BUG Invalid configuration of note plugin. typeClass required!';
            })();
            typeName = type.dataClass;
            hasTitle = !!type.hasTitle;
            label = type.label || (function() {
              throw 'BUG Invalid configuration of note plugin. label required!';
            })();
            tagName = type.tagName || 'div';
            titleTagName = type.titleTagName || 'div';
            if (typeName) {
              type.selector = "." + className + "[data-label='" + typeName + "']";
            } else {
              type.selector = "." + className + ":not([data-label])";
            }
            notishClasses[className] = true;
            newTemplate = jQuery("<" + tagName + "></" + tagName);
            newTemplate.addClass(className);
            if (typeName) {
              newTemplate.attr('data-label', typeName);
            }
            if (hasTitle) {
              newTemplate.append("<" + titleTagName + " class='title'></" + titleTagName);
            }
            UI.adopt("insert-" + className + typeName, Button, {
              click: function() {
                return semanticBlock.insertAtCursor(newTemplate.clone());
              }
            });
            if ('note' === className && !typeName) {
              UI.adopt("insertNote", Button, {
                click: function() {
                  return semanticBlock.insertAtCursor(newTemplate.clone());
                }
              });
            }
            return semanticBlock.registerEvent('click', '.aloha-oer-block.note > .type-container > ul > li > *', function(e) {
              var $el;
              $el = jQuery(this);
              $el.parents('.aloha-oer-block').first().attr('data-label', $el.text().toLowerCase());
              $el.parents('.type-container').find('.dropdown-menu li').each((function(_this) {
                return function(i, li) {
                  return jQuery(li).removeClass('checked');
                };
              })(this));
              jQuery(Aloha).trigger('aloha-smart-content-changed', {
                'triggerType': 'block-change'
              });
              return $el.parents('li').first().addClass('checked');
            });
          };
        })(this));
        return semanticBlock.register(this);
      }
    });
  });

}).call(this);
