pw.component.register('media-editor', function (view, config) {
  var self = this;
  var items = window.context._state.items;

  this.listen('media-item:toggled', function (item) {
    items = [item];

    // NOTE: below is for when we need to select multiple items (e.g. slideshow)
    // var i = items.indexOf(item);

    // if (i != -1) {
    //   items.splice(i, 1);
    // } else {
    //   items.push(item);
    // }

    var data = items.map(function (item) {
      return {
        id: item.id,
        thumb: item.thumb
      };
    });

    pw.component.broadcast('media-editor:changed', data);

    self.render();
  });

  this.render = function () {
    view.node.querySelectorAll('*[data-ui="media-item"]').forEach(function (item) {
      item.classList.remove('active');
    });

    items.forEach(function (item) {
      view.node.querySelector('*[data-id="' + item.id + '"]').classList.add('active');
    });
  };

  this.inited = function () {
    self.render();
  };
});

pw.component.register('media-item', function (view, config) {
  var self = this;

  view.node.addEventListener('click', function (evt) {
    evt.preventDefault();
    pw.component.broadcast('media-item:toggled', config);
  });
});

pw.component.register('media-upload', function (view, config) {
  var self = this;

  var field = view.node.querySelector('input');

  view.node.addEventListener('click', function (evt) {
    if (evt.target.tagName != 'INPUT') {
      evt.preventDefault();
      field.click();
    }
  });

  field.addEventListener('change', function (evt) {
    var files = evt.target.files || evt.dataTransfer.files;

    for (var i = 0, f; f = files[i]; i++) {
      self.upload(f);
    }

    evt.target.value = '';
  });

  this.upload = function (file) {
    var xhr = new XMLHttpRequest();

    if(xhr.upload) {
      xhr.open("POST", '/console/files', true);
      xhr.setRequestHeader("X_FILENAME", file.name);
      xhr.send(file);
    } else {
      console.log('err');
    }
  };
});
