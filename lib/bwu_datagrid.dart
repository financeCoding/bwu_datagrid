library bwu_dart.bwu_datagrid.datagrid;

import 'dart:async' as async;
import 'dart:math' as math;
import 'dart:html' as dom;

import 'package:polymer/polymer.dart';

import 'core/core.dart';
import 'dataview/dataview.dart';

part 'datagrid/helpers.dart';

@CustomTag('bwu-datagrid')
class BwuDatagrid extends PolymerElement {

  BwuDatagrid.created() : super.created();

  // DataGrid(dom.HtmlElement container, String data, int columns, Options options);
  dom.HtmlElement container;
  @published String data;
  @published List<int> columns;
  @published GridOptions options;

  // settings
  //GridOptions gridOptions = new GridOptions();
  ColumnOptions columnOptions = new ColumnOptions();

  dom.NodeValidator nodeValidator = new dom.NodeValidatorBuilder.common();

  // scroller
  int th;   // virtual height
  int h;    // real scrollable height
  int ph;   // page height
  int n;    // number of pages
  int cj;   // "jumpiness" coefficient

  int page = 0;       // current page
  int offset = 0;     // current page offset
  int vScrollDir = 1;

  // private
  bool initialized = false;
  dom.HtmlElement $container;
  String uid = "slickgrid_" + (1000000 * new math.Random().nextDouble()).round();
  dom.HtmlElement $focusSink, $focusSink2;
  dom.HtmlElement $headerScroller;
  dom.HtmlElement $headers;
  dom.HtmlElement $headerRow, $headerRowScroller, $headerRowSpacer;
  dom.HtmlElement $topPanelScroller;
  dom.HtmlElement $topPanel;
  dom.HtmlElement $viewport;
  dom.HtmlElement $canvas;
  dom.HtmlElement $style;
  List<dom.HtmlElement> $boundAncestors;
  dom.CssCharsetRule stylesheet, columnCssRulesL, columnCssRulesR;
  int viewportH, viewportW;
  int canvasWidth;
  bool viewportHasHScroll, viewportHasVScroll;
  int headerColumnWidthDiff = 0, headerColumnHeightDiff = 0, // border+padding
      cellWidthDiff = 0, cellHeightDiff = 0;
  int absoluteColumnMinWidth;

  int tabbingDirection = 1;
  int activePosX;
  int activeRow, activeCell;
  dom.HtmlElement activeCellNode = null;
  Editor currentEditor = null;
  String serializedEditorValue;
  int editController;

  Map<Sting,int> rowsCache = {};
  int renderedRows = 0;
  int numVisibleRows;
  int prevScrollTop = 0;
  int scrollTop = 0;
  int lastRenderedScrollTop = 0;
  int lastRenderedScrollLeft = 0;
  int prevScrollLeft = 0;
  int scrollLeft = 0;

  int selectionModel;
  List<int> selectedRows = [];

  List<int> plugins = [];
  Map<String,String> cellCssClasses = {};

  Map<String,int> columnsById = {};
  List<int> sortColumns = [];
  List<int> columnPosLeft = [];
  List<int> columnPosRight = [];


  // async call handles
  int h_editorLoader = null;
  int h_render = null;
  int h_postrender = null;
  int postProcessedRows = {};
  int postProcessToRow = null;
  int postProcessFromRow = null;

  // perf counters
  int counter_rows_rendered = 0;
  int counter_rows_removed = 0;

  // These two variables work around a bug with inertial scrolling in Webkit/Blink on Mac.
  // See http://crbug.com/312427.
  dom.HtmlElement rowNodeFromLastMouseWheelEvent;  // this node must not be deleted while inertial scrolling
  dom.HtmlElement zombieRowNodeFromLastMouseWheelEvent;  // node that was hidden instead of getting deleted

  /**
   * on before--destory
   */
  static const ON_BEFORE_DESTROY = 'before-destory';
  async.Stream<dom.CustomEvent> get onBeforeDestory =>
      BwuDatagrid._onBeforeDestory.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _onBeforeDestory =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_BEFORE_DESTROY);

  /**
   * on before-header-cell-destory
   */
  static const ON_BEFORE_HEADER_CELL_DESTROY = 'before-header-cell-destory';
  async.Stream<dom.CustomEvent> get onBeforeHeaderCellDestory =>
      BwuDatagrid._onBeforeHeaderCellDestory.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _onBeforeHeaderCellDestory =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_BEFORE_HEADER_CELL_DESTROY);

  /**
   * on header-cell-rendered
   */
  static const ON_HEADER_CELL_RENDERED = 'header-cell-rendered';
  async.Stream<dom.CustomEvent> get onHeaderCellRendered =>
      BwuDatagrid._onHeaderCellRendered.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _onHeaderCellRendered =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_HEADER_CELL_RENDERED);

  /**
   * on header-row-cell-rendered
   */
  static const ON_HEADER_ROW_CELL_RENDERED = 'header-row-cell-rendered';
  async.Stream<dom.CustomEvent> get onHeaderRowCellRendered =>
      BwuDatagrid._onHeaderRowCellRendered.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _onHeaderRowCellRendered =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_HEADER_ROW_CELL_RENDERED);


  /**
   * on sort
   */
  static const ON_SORT = 'sort';
  async.Stream<dom.CustomEvent> get onSort =>
      BwuDatagrid._onSort.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _onSort =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_SORT);

  /**
   * on columns-resized
   */
  static const ON_COLUMNS_RESIZED = 'columns-resized';
  async.Stream<dom.CustomEvent> get onColumnsResized =>
      BwuDatagrid._onColumnsResized.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _ColumnsResized =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_COLUMNS_RESIZED);

  /**
   * on columns-reordered
   */
  static const ON_COLUMNS_REORDERED = 'columns-reordered';
  async.Stream<dom.CustomEvent> get onColumnsReordered =>
      BwuDatagrid._onColumnsReordered.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _ColumnsReordered =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_COLUMNS_REORDERED);

  /**
   * on selected-rows-changed
   */
  static const ON_SELECTED_ROWS_CHANGED = 'selected-rows-changed';
  async.Stream<dom.CustomEvent> get onSelectedRowsChanged =>
      BwuDatagrid._onSelectedRowsChanged.forTarget(this);

  static const dom.EventStreamProvider<dom.CustomEvent> _onSelectedRowsChanged =
      const dom.EventStreamProvider<dom.CustomEvent>(ON_SELECTED_ROWS_CHANGED);

  //////////////////////////////////////////////////////////////////////////////////////////////
  // Initialization

  void init() {
    $container = $(container);
    if ($container.children.length < 1) {
      throw "DataGrid requires a valid container, ${container} does not exist in the DOM.";
    }

    // calculate these only once and share between grid instances
    maxSupportedCssHeight = maxSupportedCssHeight || getMaxSupportedCssHeight();
    scrollbarDimensions = scrollbarDimensions || measureScrollbar();

    //options = $.extend({}, defaults, options);
    validateAndEnforceOptions();
    columnOptions.width = gridOptions.defaultColumnWidth;

    columnsById = {};
    for (int i = 0; i < columns.length; i++) {
      ColumnOptions m = columnOptions;//columns[i] = $.extend({}, columnDefaults, columns[i]); // TODO extend
      columnsById[m.id] = i;
      if (m.minWidth && m.width < m.minWidth) {
        m.width = m.minWidth;
      }
      if (m.maxWidth && m.width > m.maxWidth) {
        m.width = m.maxWidth;
      }
    }

    // validate loaded JavaScript modules against requested options
    if (options.enableColumnReorder && !$.fn.sortable) {
      throw new Error("DataGrid's 'enableColumnReorder = true' option requires jquery-ui.sortable module to be loaded");
    }

    editController = new EditController(commitCurrentEdit, cancelCurrentEdit);

    $container
        ..children.clear() // TODO empty()
        ..style.overflow = 'hidden'
        ..style.outline = '0'
        ..classes.add(uid)
        ..classes.add("ui-widget");

    // set up a positioning container if needed
//      if (!/relative|absolute|fixed/.test($container.css("position"))) {
//        $container.css("position", "relative");
//      }
    if(!$container.style.position.contains(new RegExp('relative|absolute|fixed'))) {
      $container.style.position = 'relative';
    }

    $focusSink = new dom.Element.html("<div tabIndex='0' hideFocus style='position:fixed;width:0;height:0;top:0;left:0;outline:0;'></div>", validator: nodeValidator);
    $container.append($focusSink);

    $headerScroller = new dom.Element.html("<div class='slick-header ui-state-default' style='overflow:hidden;position:relative;' />", validator: nodeValidator);
    $container.append($headScroller);

    $headers = new dom.Element.html("<div class='slick-header-columns' style='left:-1000px' />", validator: nodeValidator);
    $headerScroller.append($headers);
    $headers.width(getHeadersWidth());

    $headerRowScroller = new dom.Element.html("<div class='slick-headerrow ui-state-default' style='overflow:hidden;position:relative;' />", validator: nodeValidator);
    $container.append($headerRowScroller);

    $headerRow = new dom.Element.html("<div class='slick-headerrow-columns' />", validator: nodeValidator);
    $headerRowScroller.append($headerRow);

    $headerRowSpacer = new dom.Element.html("<div style='display:block;height:1px;position:absolute;top:0;left:0;'></div>", validator: nodeValidator)
        ..style.width = '${getCanvasWidth() + scrollbarDimensions.width}px';
        $headerRowScroller.append($headerRowSpacer);

    $topPanelScroller = new dom.Element.html("<div class='bwu-datagrid-top-panel-scroller ui-state-default' style='overflow:hidden;position:relative;' />", validator: nodeValidator);
    $container.append($topPanelScroller);
    $topPanel = new dom.Element.html("<div class='bwu-datagrid-top-panel' style='width:10000px' />", validator: nodeValidator);
    $topPanelScroller.append($topPanel);

    if (!gridOptions.showTopPanel) {
      $topPanelScroller.hide();
    }

    if (!gridOptions.showHeaderRow) {
      $headerRowScroller.hide();
    }

    $viewport = new dom.Element.html("<div class='slick-viewport' style='width:100%;overflow:auto;outline:0;position:relative;;'>", validator: nodeValidator);
    $container.append($viewport);
    $viewport.style.overflowY = gridOptions.autoHeight ? "hidden" : "auto";

    $canvas = new dom.Element.html("<div class='grid-canvas' />", validator: nodeValidator);
    $viewport.append($canvas);

    $focusSink2 = $focusSink.clone(true);
    $container.append($focusSink2);

    if (!gridOptions.explicitInitialization) {
      finishInitialization();
    }
  }

  void finishInitialization() {
    if (!initialized) {
      initialized = true;

      viewportW = parseFloat($.css($container[0], "width", true));

      // header columns and cells may have different padding/border skewing width calculations (box-sizing, hello?)
      // calculate the diff so we can set consistent sizes
      measureCellPaddingAndBorder();

      // for usability reasons, all text selection in SlickGrid is disabled
      // with the exception of input and textarea elements (selection must
      // be enabled there so that editors work as expected); note that
      // selection in grid cells (grid body) is already unavailable in
      // all browsers except IE
      disableSelection($headers); // disable all text selection in header (including input and textarea)

      if (!gridOptions.enableTextSelectionOnCells) {
        // disable text selection in grid cells except in input and textarea elements
        // (this is IE-specific, because selectstart event will only fire in IE)
        $viewport.onSelectStart.listen((event) {  //  bind("selectstart.ui",
          return event.target is dom.InputElement || (event.target as dom.HtmlElement) is dom.TextAreaElement;
        });
      }

      updateColumnCaches();
      createColumnHeaders();
      setupColumnSort();
      createCssRules();
      resizeCanvas();
      bindAncestorScrollEvents();

      $container.on["resize.bwu-datagrid"].listen(resizeCanvas);
      //$viewport
          //.bind("click", handleClick)
      $viewport.onScroll.listen(handleScroll);
      $headerScroller..onContextMenu.listen(handleHeaderContextMenu)
          ..onClick.listen(handleHeaderClick)
          ..querySelectorAll(".bwu-datagrid-header-column").forEach((e) {
            (e as dom.HtmlElement)
            ..onMouseEnter.listen(handleHeaderMouseEnter)
            ..onMouseLeave.listen(handleHeaderMouseLeave);
      });
      $headerRowScroller
          .onScroll.listen(handleHeaderRowScroll);
      $focusSink
          ..append($focusSink2)
          ..onKeyDown.listen(handleKeyDown);
      $canvas
          ..onKeyDown.listen(handleKeyDown)
          ..onClick.listen(handleClick)
          ..onDoubleClick.listen(handleDblClick)
          ..onContextMenu.listen(handleContextMenu)
          //..bind("draginit", handleDragInit) // TODO
          ..onDragStart.listen((e) {/*{distance: 3}*/; handleDragStart(e, {distance: 3});}) // TODO what is distance?
          ..onDrag.listen(handleDrag)
          ..onDragEnd.listen(handleDragEnd)
          ..querySelectorAll(".bwu-datagrid--cell").forEach((e) {
            (e as dom.HtmlElement)
              ..onMouseEnter.listen(handleMouseEnter)
              ..onMouseLeave.listen(handleMouseLeave);
          });

      // Work around http://crbug.com/312427.
      if (dom.window.navigator.userAgent.toLowerCase().match('webkit') &&  // TODO match
          dom.window.navigator.userAgent.toLowerCase().match('macintosh')) { // TODO match
        $canvas.onMouseWheel.listen(handleMouseWheel);
      }
    }
  }

  void registerPlugin(int plugin) {
    plugins.insert(0, plugin);
    plugin.init(self);
  }

  void unregisterPlugin(int plugin) {
    for (var i = plugins.length; i >= 0; i--) {
      if (plugins[i] == plugin) {
        if (plugins[i].destroy) {
          plugins[i].destroy();
        }
        plugins.removeAt(i);
        break;
      }
    }
  }

  async.StreamSubscription onSelectedRangesChanged;
  void setSelectionModel(int model) {
    if (selectionModel != null) {
      if(onSelectedRangesChanged != null) {
        onSelectedRangesChanged.cancel(); //selectionModel.onSelectedRangesChanged.unsubscribe(handleSelectedRangesChanged);
      }
      if (selectionModel.destroy) {
        selectionModel.destroy();
      }
    }

    selectionModel = model;
    if (selectionModel) {
      selectionModel.init(self);
      onSelectedRangesChanged = selectionModel.onSelectedRangesChanged.listen(handleSelectedRangesChanged);
    }
  }

  int get getSelectionModel => selectionModel;

  dom.HtmlElement get getCanvasNode => $canvas[0];

  math.Point measureScrollbar() {
    var $c = new dom.Element.html("<div style='position:absolute; top:-10000px; left:-10000px; width:100px; height:100px; overflow:scroll;'></div>", validator: nodeValidator);
    dom.document.body.append($c);
    var dim = new math.Point($c.width() - $c[0].clientWidth, $c.height() - $c[0].clientHeight);
    $c.remove();
    return dim;
  }

  int getHeadersWidth() {
    var headersWidth = 0;
    int ii = columns.length;
    for (int i = 0;  i < ii; i++) {
      int width = columns[i].width;
      headersWidth += width;
    }
    headersWidth += scrollbarDimensions.width;
    return math.max(headersWidth, viewportW) + 1000;
  }

  int getCanvasWidth() {
    int availableWidth = viewportHasVScroll ? viewportW - scrollbarDimensions.width : viewportW;
    int rowWidth = 0;
    int i = columns.length;
    while (i--) {
      rowWidth += columns[i].width;
    }
    return gridOptions.fullWidthRows ? math.max(rowWidth, availableWidth) : rowWidth;
  }

  void updateCanvasWidth(forceColumnWidthsUpdate) {
    int oldCanvasWidth = canvasWidth;
    canvasWidth = getCanvasWidth();

    if (canvasWidth != oldCanvasWidth) {
      $canvas.style.width = canvasWidth;
      $headerRow.style.width = canvasWidth;
      $headers.style.width =getHeadersWidth();
      viewportHasHScroll = (canvasWidth > viewportW - scrollbarDimensions.width);
    }

    $headerRowSpacer.style.width(canvasWidth + (viewportHasVScroll ? scrollbarDimensions.width : 0));

    if (canvasWidth != oldCanvasWidth || forceColumnWidthsUpdate) {
      applyColumnWidths();
    }
  }

  void disableSelection(dom.HtmlElement $target) {
    if ($target != null) {
      $target
        ..attributes["unselectable"] = "on"
        ..style.userSelect= "none"
        ..onSelectStart.listen((e) {
          e
           ..stopPropagation()
           ..stopImmediatePropagation();
        }); // bind("selectstart.ui", function () {
    }
  }

  int getMaxSupportedCssHeight() {
    int supportedHeight = 1000000;
    // FF reports the height back but still renders blank after ~6M px
    int testUpTo = dom.window.navigator.userAgent.toLowerCase().match('firefox') ? 6000000 : 1000000000; // TODO check match
    var div = new dom.Element.html("<div style='display:none' />", validator: nodeValidator);
    dom.document.body.append(div);

    while (true) {
      int test = supportedHeight * 2;
      div.style.height = test;
      if (test > testUpTo || div.style.height != test) { // parse height
        break;
      } else {
        supportedHeight = test;
      }
    }

    div.remove();
    return supportedHeight;
  }

  // TODO:  this is static.  need to handle page mutation.
  void bindAncestorScrollEvents() {
    var elem = $canvas.children[0];
    while ((elem = elem.parentNode) != document.body && elem != null) {
      // bind to scroll containers only
      if (elem == $viewport.children[0] || elem.scrollWidth != elem.clientWidth || elem.scrollHeight != elem.clientHeight) {
        var $elem = elem;
        if (!$boundAncestors) {
          $boundAncestors = $elem;
        } else {
          $boundAncestors = $boundAncestors.add($elem);
        }
        $elem.bind("scroll." + uid, handleActiveCellPositionChange); // TODO scroll.+uid
      }
    }
  }

  void unbindAncestorScrollEvents() {
    if (!$boundAncestors) {
      return;
    }
    $boundAncestors.unbind("scroll." + uid);
    $boundAncestors = null;
  }

  void updateColumnHeader(String columnId, String title, String toolTip) {
    if (!initialized) { return; }
    var idx = getColumnIndex(columnId);
    if (idx == null) {
      return;
    }

    int columnDef = columns[idx];
    dom.HtmlElement $header = $headers.children.where((e) => e.id == idx); //().eq(idx); // TODO check
    if ($header != null) {
      if (title != null) {
        columns[idx].name = title;
      }
      if (toolTip != null) {
        columns[idx].toolTip = toolTip;
      }

      fire(ON_BEFORE_HEADER_CELL_DESTROY, detail: {
        "node": $header.children[0],
        "column": columnDef
      });

      $header
          ..attributes["title"] = toolTip != null ? tootip : ""
          ..children.where((e) => e.id == 0).forEach((e) => e.innerHtml = title); //().eq(0).html(title); // TODO check

      fire(ON_HEADER_CELL_RENDERED, detail: {
        "node": $header.children[0],
        "column": columnDef
      });
    }
  }

  dom.HtmlElement getHeaderRow() {
    return $headerRow.children[0];
  }

  int getHeaderRowColumn(columnId) {
    var idx = getColumnIndex(columnId);
    var $header = $headerRow.children.where((e) => e == idx); //.eq(idx); // TODO check
    return $header && $header[0];
  }

  void createColumnHeaders() {
    var onMouseEnter = () {
      classes.add("ui-state-hover");
    };

    var onMouseLeave = () {
      classes.remove("ui-state-hover");
    };

    $headers.querySelectorAll(".bwu-datagrid-header-column")
      .forEach((dom.HtmlElement e) { // TODO check self/this
        var columnDef = e.dataset["column"];
        if (columnDef != null) {
          fire(ON_BEFORE_HEADER_CELL_DESTROY, detail: {
            "node": e,
            "column": columnDef
          });
        }
      });
    $headers.children.clear();
    $headers.style.width = getHeadersWidth();

    $headerRow.querySelectorAll(".bwu-datagrid-headerrow-column")
      .forEach((dom.HtmlElement e) { // TODO check self/this
        var columnDef = e.dataset["column"];
        if (columnDef) {
          fire(ON_BEFORE_HEADER_CELL_DESTROY, detail: {
            "node": e,
            "column": columnDef
          });
        }
      });
    $headerRow.children.clear();

    for (int i = 0; i < columns.length; i++) {
      var m = columns[i];

      var header = new dom.Element.html("<div class='ui-state-default slick-header-column' />", validator: nodeValidator)
          ..append(new dom.Element.html("<span class='slick-column-name'>" + m.name + "</span>", validator: nodeValidator))
          ..style.width = m.width - headerColumnWidthDiff
          ..attributes["id"] ='${uid}${m.id}'
          ..attributes["title"] = m.toolTip != null ? m.toolTip : ""
          ..dataset["column"] = m
          ..classes.add(m.headerCssClass != null ? m.headerCssClass : "");
      $headers.append(header);

      if (options.enableColumnReorder || m.sortable) {
        header
          ..onMouseEnter.listen(onMouseEnter)
          ..onMouseLeave.listen(onMouseLeave);
      }

      if (m.sortable) {
        header.classes.add("bwu-datagrid-header-sortable");
        header.append(new dom.Element.html("<span class='slick-sort-indicator' />", validator: nodeValidator));
      }

      fire(ON_HEADER_CELL_RENDERED, detail: {
        "node": header[0],
        "column": m
      });

      if (options.showHeaderRow) {
        var headerRowCell = new dom.Element.html("<div class='ui-state-default slick-headerrow-column l${i} r${i}'></div>", validator: nodeValidator)
            ..dataset["column"] =  m;
            $headerRow.append(headerRowCell);

        fire(ON_HEADER_ROW_CELL_RENDERED, detail: {
          "node": headerRowCell.children[0],
          "column": m
        });
      }
    }

    setSortColumns(sortColumns);
    setupColumnResize();
    if (options.enableColumnReorder) {
      setupColumnReorder();
    }
  }

  void setupColumnSort() {
    $headers.onClick.listen((e) {
      // temporary workaround for a bug in jQuery 1.7.1 (http://bugs.jquery.com/ticket/11328)
      e.metaKey = e.metaKey || e.ctrlKey;

      if ((e.target as dom.HtmlElement).classes.contains("bwu-datagrid-resizable-handle")) {
        return;
      }

      dom.HtmlElement $col = (e.target as dom.HtmlElement).querySelector(".slick-header-column"); // TODO check var $col = $(e.target).closest(".slick-header-column");
      if ($col.children.length) {
        return;
      }

      int column = $col.dataset["column"];
      if (column.sortable) {
        if (!getEditorLock().commitCurrentEdit()) {
          return;
        }

        var sortOpts = null;
        var i = 0;
        for (; i < sortColumns.length; i++) {
          if (sortColumns[i].columnId == column.id) {
            sortOpts = sortColumns[i];
            sortOpts.sortAsc = !sortOpts.sortAsc;
            break;
          }
        }

        if (e.metaKey && options.multiColumnSort) {
          if (sortOpts) {
            sortColumns.splice(i, 1);
          }
        }
        else {
          if ((!e.shiftKey && !e.metaKey) || !options.multiColumnSort) {
            sortColumns = [];
          }

          if (!sortOpts) {
            sortOpts = { columnId: column.id, sortAsc: column.defaultSortAsc };
            sortColumns.add(sortOpts);
          } else if (sortColumns.length == 0) {
            sortColumns.add(sortOpts);
          }
        }

        setSortColumns(sortColumns);

        if (!options.multiColumnSort) {
          fire(ON_SORT, detail: {
            'multiColumnSort': false,
            'sortCol': column,
            'sortAsc': sortOpts.sortAsc,
            'caused_by': e});
        } else {
          fire(ON_SORT, detail: {
            'multiColumnSort': true,
            'sortCols': $.map(sortColumns, (col) { // TODO map
              return {'sortCol': columns[getColumnIndex(col.columnId)], 'sortAsc': col.sortAsc };
            }),
            'caused_by': e});
        }
      }
    });
  }

  void setupColumnReorder() {
    $headers.filter(":ui-sortable").sortable("destroy");
    $headers.sortable({
      'containment': "parent",
      'distance': 3,
      'axis': "x",
      'cursor': "default",
      'tolerance': "intersection",
      'helper': "clone",
      'placeholder': "slick-sortable-placeholder ui-state-default slick-header-column",
      'start': (e, ui) {
        ui.placeholder.width(ui.helper.outerWidth() - headerColumnWidthDiff);
        (ui.helper as dom.HtmlElement).classes.add("beu-datagrid-header-column-active");
      },
      'beforeStop': (e, ui) {
        (ui.helper as dom.HtmlElement).classes.remove("bwu-datagrid-header-column-active");
      },
      'stop': (e) {
        if (!getEditorLock().commitCurrentEdit()) {
          $(this).sortable("cancel"); // TODO
          return;
        }

        var reorderedIds = $headers.sortable("toArray");
        var reorderedColumns = [];
        for (var i = 0; i < reorderedIds.length; i++) {
          reorderedColumns.push(columns[getColumnIndex(reorderedIds[i].replace(uid, ""))]);
        }
        setColumns(reorderedColumns);

        fire(ON_COLUMNS_REORDERED, detail: {});
        e.stopPropagation();
        setupColumnResize();
      }
    });
  }

  void setupColumnResize() {
    dom.HtmlElement $col;
    int j;
    int c;
    int pageX;
    List<dom.HtmlElement> columnElements;
    int minPageX, maxPageX;
    bool firstResizable, lastResizable;
    columnElements = $headers.children;
    columnElements.querySelectorAll(".bwu-datagrid-resizable-handle").remove();
    columnElements.forEach( (i, e) {
      if (columns[i].resizable) {
        if (firstResizable == null) {
          firstResizable = i;
        }
        lastResizable = i;
      }
    });
    if (firstResizable == null) {
      return;
    }
    columnElements.forEach((i, e) {
      if (i < firstResizable || (options.forceFitColumns && i >= lastResizable)) {
        return;
      }
      $col = (e as dom.HtmlElement);
      var div = new dom.Element.html("<div class='bwu-datagrid-resizable-handle' />", validator: nodeValidator);
      e.append(div);
          div..onDragStart.listen((e, dd) {
            if (!getEditorLock.commitCurrentEdit()) {
              return false;
            }
            pageX = e.pageX;
            (e as dom.HtmlElement).parent.classes.add("bwu-datagrid-header-column-active");
            int shrinkLeewayOnRight = null, stretchLeewayOnRight = null;
            // lock each column's width option to current width
            columnElements.forEach((i, e) {
              columns[i].previousWidth = (e as dom.htmlElement).outerWidth();
            });
            if (options.forceFitColumns) {
              shrinkLeewayOnRight = 0;
              stretchLeewayOnRight = 0;
              // colums on right affect maxPageX/minPageX
              for (j = i + 1; j < columnElements.length; j++) {
                c = columns[j];
                if (c.resizable) {
                  if (stretchLeewayOnRight != null) {
                    if (c.maxWidth) {
                      stretchLeewayOnRight += c.maxWidth - c.previousWidth;
                    } else {
                      stretchLeewayOnRight = null;
                    }
                  }
                  shrinkLeewayOnRight += c.previousWidth - math.max(c.minWidth || 0, absoluteColumnMinWidth);
                }
              }
            }
            int shrinkLeewayOnLeft = 0, stretchLeewayOnLeft = 0;
            for (j = 0; j <= i; j++) {
              // columns on left only affect minPageX
              c = columns[j];
              if (c.resizable) {
                if (stretchLeewayOnLeft != null) {
                  if (c.maxWidth) {
                    stretchLeewayOnLeft += c.maxWidth - c.previousWidth;
                  } else {
                    stretchLeewayOnLeft = null;
                  }
                }
                shrinkLeewayOnLeft += c.previousWidth - Math.max(c.minWidth || 0, absoluteColumnMinWidth);
              }
            }
            if (shrinkLeewayOnRight == null) {
              shrinkLeewayOnRight = 100000;
            }
            if (shrinkLeewayOnLeft == null) {
              shrinkLeewayOnLeft = 100000;
            }
            if (stretchLeewayOnRight == null) {
              stretchLeewayOnRight = 100000;
            }
            if (stretchLeewayOnLeft == null) {
              stretchLeewayOnLeft = 100000;
            }
            maxPageX = pageX + Math.min(shrinkLeewayOnRight, stretchLeewayOnLeft);
            minPageX = pageX - Math.min(shrinkLeewayOnLeft, stretchLeewayOnRight);
          })
          ..onDrag.listen((e, dd) {
            var actualMinWidth, d = math.min(maxPageX, Math.max(minPageX, e.pageX)) - pageX, x;
            if (d < 0) { // shrink column
              x = d;
              for (j = i; j >= 0; j--) {
                c = columns[j];
                if (c.resizable) {
                  actualMinWidth = math.max(c.minWidth || 0, absoluteColumnMinWidth);
                  if (x && c.previousWidth + x < actualMinWidth) {
                    x += c.previousWidth - actualMinWidth;
                    c.width = actualMinWidth;
                  } else {
                    c.width = c.previousWidth + x;
                    x = 0;
                  }
                }
              }

              if (options.forceFitColumns) {
                x = -d;
                for (j = i + 1; j < columnElements.length; j++) {
                  c = columns[j];
                  if (c.resizable) {
                    if (x && c.maxWidth && (c.maxWidth - c.previousWidth < x)) {
                      x -= c.maxWidth - c.previousWidth;
                      c.width = c.maxWidth;
                    } else {
                      c.width = c.previousWidth + x;
                      x = 0;
                    }
                  }
                }
              }
            } else { // stretch column
              x = d;
              for (j = i; j >= 0; j--) {
                c = columns[j];
                if (c.resizable) {
                  if (x && c.maxWidth && (c.maxWidth - c.previousWidth < x)) {
                    x -= c.maxWidth - c.previousWidth;
                    c.width = c.maxWidth;
                  } else {
                    c.width = c.previousWidth + x;
                    x = 0;
                  }
                }
              }

              if (options.forceFitColumns) {
                x = -d;
                for (j = i + 1; j < columnElements.length; j++) {
                  c = columns[j];
                  if (c.resizable) {
                    actualMinWidth = Math.max(c.minWidth || 0, absoluteColumnMinWidth);
                    if (x && c.previousWidth + x < actualMinWidth) {
                      x += c.previousWidth - actualMinWidth;
                      c.width = actualMinWidth;
                    } else {
                      c.width = c.previousWidth + x;
                      x = 0;
                    }
                  }
                }
              }
            }
            applyColumnHeaderWidths();
            if (options.syncColumnCellResize) {
              applyColumnWidths();
            }
          })
          ..onDtragEnd.listen((e, dd) {
            var newWidth;
            (e as dom.HtmlElement).parent().classes.add("bwu-datagrid-header-column-active");
            for (j = 0; j < columnElements.length; j++) {
              c = columns[j];
              newWidth = $(columnElements[j]).outerWidth();

              if (c.previousWidth != newWidth && c.rerenderOnResize) {
                invalidateAllRows();
              }
            }
            updateCanvasWidth(true);
            render();
            fire(ON_COLUMNS_RESIZED, detail: {});
          });
    });
  }

  int getVBoxDelta(dom.HtmlElement $el) {
    var p = ["borderTopWidth", "borderBottomWidth", "paddingTop", "paddingBottom"];
    var delta = 0;
    p.forEach((val) {
      delta += parseFloat($el.css(val)) || 0; // TODO
    });
    return delta;
  }

  void measureCellPaddingAndBorder() {
    var el;
    var h = ["borderLeftWidth", "borderRightWidth", "paddingLeft", "paddingRight"];
    var v = ["borderTopWidth", "borderBottomWidth", "paddingTop", "paddingBottom"];

    el = new dom.Element.html("<div class='ui-state-default slick-header-column' style='visibility:hidden'>-</div>", validator: nodeValidator);
    $headers.append(el);
    headerColumnWidthDiff = headerColumnHeightDiff = 0;
    if (el.style.boxSizing != "border-box") {
      h.forEach((val) {
        headerColumnWidthDiff += parseFloat(el.css(val)) || 0; // TODO
      });
      v.forEach((val) {
        headerColumnHeightDiff += parseFloat(el.css(val)) || 0; // TODO
      });
    }
    el.remove();

    var r = new dom.Element.html("<div class='slick-row' />", validator: nodeValidator);
    $canvas.append(r);
    el = new dom.Element.html("<div class='slick-cell' id='' style='visibility:hidden'>-</div>", validator: nodeValidator);
    r.append(el);
    cellWidthDiff = cellHeightDiff = 0;
    if (el.style.boxSizing != "border-box") {
      h.forEach((val) {
        cellWidthDiff += parseFloat(el.css(val)) || 0; // TODO
      });
      v.forEach((val) {
        cellHeightDiff += parseFloat(el.css(val)) || 0; // TODO
      });
    }
    r.remove();

    absoluteColumnMinWidth = math.max(headerColumnWidthDiff, cellWidthDiff);
  }

  void createCssRules() {
    $style = new dom.Element.html("<style type='text/css' rel='stylesheet' />", validator: nodeValidator);
    dom.document.head.append($style);
    var rowHeight = (options.rowHeight - cellHeightDiff);
    var rules = [
      ".${uid} .bwu-datagrid-header-column { left: 1000px; }",
      ".${uid} .bwu-datagrid-top-panel { height:${options.topPanelHeight}px; }",
      ".${uid} .bwu-datagrid-headerrow-columns { height:${options.headerRowHeight}px; }",
      ".${uid} .bwu-datagrid-cell { height:${rowHeight}px; }",
      ".${uid} .bwu-datagrid-row { height:${options.rowHeight}px; }"
    ];

    for (int i = 0; i < columns.length; i++) {
      rules.add(".${uid} .l${i} { }");
      rules.add(".${uid} .r${i} { }");
    }

    if ($style.children[0].styleSheet) { // IE
      $style.children[0].styleSheet.cssText = rules.join(" ");
    } else {
      $style.children[0].appendChild(dom.document.createTextNode(rules.join(" ")));
    }
  }

  void getColumnCssRules(int idx) {
    if (!stylesheet) {
      var sheets = dom.document.styleSheets;
      for (int i = 0; i < sheets.length; i++) {
        if ((sheets[i].ownerNode || sheets[i].owningElement) == $style.children[0]) {
          stylesheet = sheets[i];
          break;
        }
      }

      if (!stylesheet) {
        throw new Error("Cannot find stylesheet.");
      }

      // find and cache column CSS rules
      columnCssRulesL = [];
      columnCssRulesR = [];
      var cssRules = (stylesheet.cssRules || stylesheet.rules);
      var matches, columnIdx;
      for (var i = 0; i < cssRules.length; i++) {
        var selector = cssRules[i].selectorText;
        if (matches = new RegExp(r'\.l\d+').exec(selector)) {
          columnIdx = parseInt(matches[0].substr(2, matches[0].length - 2), 10);
          columnCssRulesL[columnIdx] = cssRules[i];
        } else if (matches = new RegExp(r'\.r\d+'.exec(selector)) {
          columnIdx = parseInt(matches[0].substr(2, matches[0].length - 2), 10);
          columnCssRulesR[columnIdx] = cssRules[i];
        }
      }
    }

    return {
      "left": columnCssRulesL[idx],
      "right": columnCssRulesR[idx]
    };
  }

  void removeCssRules() {
    $style.remove();
    stylesheet = null;
  }

  void destroy() {
    getEditorLock.cancelCurrentEdit();

    fire(ON_BEFORE_DESTROY, detail: {});

    var i = plugins.length;
    while(i--) {
      unregisterPlugin(plugins[i]);
    }

    if (options.enableColumnReorder) {
        $headers.filter(":ui-sortable").sortable("destroy"); // TODO
    }

    unbindAncestorScrollEvents();
    $container.unbind(".bwu-datagrid"); // TODO
    removeCssRules();

    $canvas.unbind("draginit dragstart dragend drag");
    $container.empty().removeClass(uid);
  }


  //////////////////////////////////////////////////////////////////////////////////////////////
  // General

//  function trigger(evt, args, e) {
//    e = e || new Slick.EventData();
//    args = args || {};
//    args.grid = self;
//    return evt.notify(args, e, self);
//  }

  String get getEditorLock => options.editorLock;

  String get getEditController => editController;
  }

  String getColumnIndex(id) => columnsById[id];

  void autosizeColumns() {
    var i, c,
        widths = [],
        shrinkLeeway = 0,
        total = 0,
        prevTotal,
        availWidth = viewportHasVScroll ? viewportW - scrollbarDimensions.width : viewportW;

    for (i = 0; i < columns.length; i++) {
      c = columns[i];
      widths.push(c.width);
      total += c.width;
      if (c.resizable) {
        shrinkLeeway += c.width - math.max(c.minWidth, absoluteColumnMinWidth);
      }
    }

    // shrink
    prevTotal = total;
    while (total > availWidth && shrinkLeeway) {
      var shrinkProportion = (total - availWidth) / shrinkLeeway;
      for (i = 0; i < columns.length && total > availWidth; i++) {
        c = columns[i];
        var width = widths[i];
        if (!c.resizable || width <= c.minWidth || width <= absoluteColumnMinWidth) {
          continue;
        }
        var absMinWidth = math.max(c.minWidth, absoluteColumnMinWidth);
        var shrinkSize = (shrinkProportion * (width - absMinWidth)).floor() || 1;
        shrinkSize = math.min(shrinkSize, width - absMinWidth);
        total -= shrinkSize;
        shrinkLeeway -= shrinkSize;
        widths[i] -= shrinkSize;
      }
      if (prevTotal <= total) {  // avoid infinite loop
        break;
      }
      prevTotal = total;
    }

    // grow
    prevTotal = total;
    while (total < availWidth) {
      var growProportion = availWidth / total;
      for (i = 0; i < columns.length && total < availWidth; i++) {
        c = columns[i];
        var currentWidth = widths[i];
        var growSize;

        if (!c.resizable || c.maxWidth <= currentWidth) {
          growSize = 0;
        } else {
          growSize = Math.min(Math.floor(growProportion * currentWidth) - currentWidth, (c.maxWidth - currentWidth) || 1000000) || 1;
        }
        total += growSize;
        widths[i] += growSize;
      }
      if (prevTotal >= total) {  // avoid infinite loop
        break;
      }
      prevTotal = total;
    }

    var reRender = false;
    for (i = 0; i < columns.length; i++) {
      if (columns[i].rerenderOnResize && columns[i].width != widths[i]) {
        reRender = true;
      }
      columns[i].width = widths[i];
    }

    applyColumnHeaderWidths();
    updateCanvasWidth(true);
    if (reRender) {
      invalidateAllRows();
      render();
    }
  }

  void applyColumnHeaderWidths() {
    if (!initialized) { return; }
    var h;
    for (int i = 0; i < $headers.children.length; i++) {
      h = $(headers[i]);
      if (h.width() != columns[i].width - headerColumnWidthDiff) {
        h.width(columns[i].width - headerColumnWidthDiff);
      }
    }

    updateColumnCaches();
  }

  void applyColumnWidths() {
    int x = 0;
    int w;
    dom.CssStyleRule rule;
    for (var i = 0; i < columns.length; i++) {
      w = columns[i].width;

      rule = getColumnCssRules(i);
      rule.left.style.left = '${x}px';
      rule.right.style.right = '${(canvasWidth - x - w)}px';

      x += columns[i].width;
    }
  }

  void setSortColumn(int columnId, bool ascending) {
    setSortColumns([{ columnId: columnId, sortAsc: ascending}]);
  }

  void setSortColumns(List<int> cols) {
    sortColumns = cols;

    var headerColumnEls = $headers.children;
    headerColumnEls
        ..classes.remove("bwu-datagrid-header-column-sorted")
        .querySelectorAll(".bwu-datagrid-sort-indicator").forEach((dom.HtmlElement e) =>
            e.classes
            ..remove('bwu-datagrid-sort-indicator-asc')
            ..remove('bwu-datagrid-sort-indicator-desc'));

    sortColumns.forEach((col) {
      if (col.sortAsc == null) {
        col.sortAsc = true;
      }
      var columnIndex = getColumnIndex(col.columnId);
      if (columnIndex != null) {
        headerColumnEls.eq(columnIndex) // TODO
            .addClass("slick-header-column-sorted")
            .find(".slick-sort-indicator")
                .addClass(col.sortAsc ? "slick-sort-indicator-asc" : "slick-sort-indicator-desc");
      }
    });
  }

  List<int> get getSortColumns =>sortColumns;

  void handleSelectedRangesChanged(CustomEvent e, List<Range> ranges) {
    selectedRows = [];
    var hash = {};
    for (var i = 0; i < ranges.length; i++) {
      for (var j = ranges[i].fromRow; j <= ranges[i].toRow; j++) {
        if (!hash[j]) {  // prevent duplicates
          selectedRows.add(j);
          hash[j] = {};
        }
        for (var k = ranges[i].fromCell; k <= ranges[i].toCell; k++) {
          if (canCellBeSelected(j, k)) {
            hash[j][columns[k].id] = options.selectedCellCssClass;
          }
        }
      }
    }

    setCellCssStyles(options.selectedCellCssClass, hash);

    fire(ON_SELECTED_ROWS_CHANGED , detail:{'rows': getSelectedRows(), 'caused_by': e});
  }

  List<int> get getColumns => columns;

  void updateColumnCaches() {
    // Pre-calculate cell boundaries.
    columnPosLeft = [];
    columnPosRight = [];
    var x = 0;
    for (var i = 0; i < columns.length; i++) {
      columnPosLeft[i] = x;
      columnPosRight[i] = x + columns[i].width;
      x += columns[i].width;
    }
  }

  void setColumns(List<int> columnDefinitions) {
    columns = columnDefinitions;

    columnsById = {};
    for (var i = 0; i < columns.length; i++) {
      var m = columns[i] = $.extend({}, columnDefaults, columns[i]);
      columnsById[m.id] = i;
      if (m.minWidth && m.width < m.minWidth) {
        m.width = m.minWidth;
      }
      if (m.maxWidth && m.width > m.maxWidth) {
        m.width = m.maxWidth;
      }
    }

    updateColumnCaches();

    if (initialized) {
      invalidateAllRows();
      createColumnHeaders();
      removeCssRules();
      createCssRules();
      resizeCanvas();
      applyColumnWidths();
      handleScroll();
    }
  }

  GridOptions get getOptions => options;

  void set setOptions(GridOptions args) {
    if (!getEditorLock.commitCurrentEdit()) {
      return;
    }

    makeActiveCellNormal();

    if (options.enableAddRow != args.enableAddRow) {
      invalidateRow(getDataLength());
    }

    options = $.extend(options, args);
    validateAndEnforceOptions();

    $viewport.css("overflow-y", options.autoHeight ? "hidden" : "auto");
    render();
  }

  void validateAndEnforceOptions() {
    if (options.autoHeight) {
      options.leaveSpaceForNewRows = false;
    }
  }

  function setData(newData, scrollToTop) {
    data = newData;
    invalidateAllRows();
    updateRowCount();
    if (scrollToTop) {
      scrollTo(0);
    }
  }

  function getData() {
    return data;
  }

  function getDataLength() {
    if (data.getLength) {
      return data.getLength();
    } else {
      return data.length;
    }
  }

  function getDataLengthIncludingAddNew() {
    return getDataLength() + (options.enableAddRow ? 1 : 0);
  }

  int getDataItem(int i) {
    if (data.getItem) {
      return data.getItem(i);
    } else {
      return data[i];
    }
  }

  int get getTopPanel => $topPanel[0];

  void set setTopPanelVisibility(visible) {
    if (options.showTopPanel != visible) {
      options.showTopPanel = visible;
      if (visible) {
        $topPanelScroller.slideDown("fast", resizeCanvas);
      } else {
        $topPanelScroller.slideUp("fast", resizeCanvas);
      }
    }
  }

  void set setHeaderRowVisibility(bool visible) {
    if (options.showHeaderRow != visible) {
      options.showHeaderRow = visible;
      if (visible) {
        $headerRowScroller.slideDown("fast", resizeCanvas);
      } else {
        $headerRowScroller.slideUp("fast", resizeCanvas);
      }
    }
  }

  int get getContainerNode => $container.get(0);

  //////////////////////////////////////////////////////////////////////////////////////////////
  // Rendering / Scrolling

  int getRowTop(int row) {
    return options.rowHeight * row - offset;
  }

  int getRowFromPosition(y) {
    return Math.floor((y + offset) / options.rowHeight);
  }

  void scrollTo(int y) {
    y = Math.max(y, 0);
    y = Math.min(y, th - viewportH + (viewportHasHScroll ? scrollbarDimensions.height : 0));

    var oldOffset = offset;

    page = math.min(n - 1, (y / ph).floor());
    offset = Math.round(page * cj);
    var newScrollTop = y - offset;

    if (offset != oldOffset) {
      var range = getVisibleRange(newScrollTop);
      cleanupRows(range);
      updateRowPositions();
    }

    if (prevScrollTop != newScrollTop) {
      vScrollDir = (prevScrollTop + oldOffset < newScrollTop + offset) ? 1 : -1;
      $viewport[0].scrollTop = (lastRenderedScrollTop = scrollTop = prevScrollTop = newScrollTop);

      trigger(self.onViewportChanged, {});
    }
  }

  String defaultFormatter(int row, int cell, int value, int columnDef, int dataContext) {
    if (value == null) {
      return "";
    } else {
      return (value + "").replace(r'&',"&amp;").replace(r'<',"&lt;").replace(r'>',"&gt;");
    }
  }

  Function getFormatter(row, column) {
    var rowMetadata = data.getItemMetadata && data.getItemMetadata(row);

    // look up by id, then index
    var columnOverrides = rowMetadata &&
        rowMetadata.columns &&
        (rowMetadata.columns[column.id] || rowMetadata.columns[getColumnIndex(column.id)]);

    return (columnOverrides && columnOverrides.formatter) ||
        (rowMetadata && rowMetadata.formatter) ||
        column.formatter ||
        (options.formatterFactory && options.formatterFactory.getFormatter(column)) ||
        options.defaultFormatter;
  }

  int getEditor(int row, int cell) {
    var column = columns[cell];
    var rowMetadata = data.getItemMetadata && data.getItemMetadata(row);
    var columnMetadata = rowMetadata && rowMetadata.columns;

    if (columnMetadata && columnMetadata[column.id] && columnMetadata[column.id].editor != null) {
      return columnMetadata[column.id].editor;
    }
    if (columnMetadata && columnMetadata[cell] && columnMetadata[cell].editor != null) {
      return columnMetadata[cell].editor;
    }

    return column.editor || (options.editorFactory && options.editorFactory.getEditor(column));
  }

  int getDataItemValueForColumn(int item, int columnDef) {
    if (options.dataItemColumnValueExtractor) {
      return options.dataItemColumnValueExtractor(item, columnDef);
    }
    return item[columnDef.field];
  }

  void appendRowHtml(List<String> stringArray, int row, Range range, int dataLength) {
    var d = getDataItem(row);
    var dataLoading = row < dataLength && !d;
    var rowCss = "bwu-datagrid-row" +
        (dataLoading ? " loading" : "") +
        (row == activeRow ? " active" : "") +
        (row % 2 == 1 ? " odd" : " even");

    if (!d) {
      rowCss += " " + options.addNewRowCssClass;
    }

    var metadata = data.getItemMetadata && data.getItemMetadata(row);

    if (metadata && metadata.cssClasses) {
      rowCss += " " + metadata.cssClasses;
    }

    stringArray.add("<div class='ui-widget-content ${rowCss}' style='top:${getRowTop(row)}px'>");

    var colspan, m;
    for (var i = 0, ii = columns.length; i < ii; i++) {
      m = columns[i];
      colspan = 1;
      if (metadata && metadata.columns) {
        var columnData = metadata.columns[m.id] || metadata.columns[i];
        colspan = (columnData && columnData.colspan) || 1;
        if (colspan == "*") {
          colspan = ii - i;
        }
      }

      // Do not render cells outside of the viewport.
      if (columnPosRight[math.min(ii - 1, i + colspan - 1)] > range.leftPx) {
        if (columnPosLeft[i] > range.rightPx) {
          // All columns to the right are outside the range.
          break;
        }

        appendCellHtml(stringArray, row, i, colspan, d);
      }

      if (colspan > 1) {
        i += (colspan - 1);
      }
    }

    stringArray.add("</div>");
  }

  void appendCellHtml(List<String>stringArray, int row, int cell, String colspan, int item) {
    var m = columns[cell];
    var cellCss = "slick-cell l" + cell + " r" + math.min(columns.length - 1, cell + colspan - 1) +
        (m.cssClass ? " " + m.cssClass : "");
    if (row == activeRow && cell == activeCell) {
      cellCss += (" active");
    }

    // TODO:  merge them together in the setter
    for (var key in cellCssClasses) {
      if (cellCssClasses[key][row] && cellCssClasses[key][row][m.id]) {
        cellCss += (" " + cellCssClasses[key][row][m.id]);
      }
    }

    stringArray.add("<div class='${cellCss}'>");

    // if there is a corresponding row (if not, this is the Add New row or this data hasn't been loaded yet)
    if (item != null) {
      var value = getDataItemValueForColumn(item, m);
      stringArray.push(getFormatter(row, m)(row, cell, value, m, item));
    }

    stringArray.add("</div>");

    rowsCache[row].cellRenderQueue.push(cell);
    rowsCache[row].cellColSpans[cell] = colspan;
  }


  void cleanupRows(Range rangeToKeep) {
    for (var i in rowsCache) {
      if (((i = parseInt(i, 10)) != activeRow) && (i < rangeToKeep.top || i > rangeToKeep.bottom)) {
        removeRowFromCache(i);
      }
    }
  }

  void invalidate() {
    updateRowCount();
    invalidateAllRows();
    render();
  }

  void invalidateAllRows() {
    if (currentEditor) {
      makeActiveCellNormal();
    }
    for (var row in rowsCache) {
      removeRowFromCache(row);
    }
  }

  void removeRowFromCache(row) {
    var cacheEntry = rowsCache[row];
    if (!cacheEntry) {
      return;
    }

    if (rowNodeFromLastMouseWheelEvent == cacheEntry.rowNode) {
      cacheEntry.rowNode.style.display = 'none';
      zombieRowNodeFromLastMouseWheelEvent = rowNodeFromLastMouseWheelEvent;
    } else {
      $canvas.children[0].removeChild(cacheEntry.rowNode);
    }

    rowsCache.remove(row);
    postProcessedRows.remove(row);
    renderedRows--;
    counter_rows_removed++;
  }

  void invalidateRows(rows) {
    var i, rl;
    if (!rows || !rows.length) {
      return;
    }
    vScrollDir = 0;
    for (i = 0; i < rows.length; i++) {
      if (currentEditor && activeRow == rows[i]) {
        makeActiveCellNormal();
      }
      if (rowsCache[rows[i]]) {
        removeRowFromCache(rows[i]);
      }
    }
  }

  void invalidateRow(int row) {
    invalidateRows(row);
  }

  void updateCell(int row, int cell) {
    var cellNode = getCellNode(row, cell);
    if (!cellNode) {
      return;
    }

    var m = columns[cell], d = getDataItem(row);
    if (currentEditor && activeRow == row && activeCell == cell) {
      currentEditor.loadValue(d);
    } else {
      cellNode.innerHTML = d ? getFormatter(row, m)(row, cell, getDataItemValueForColumn(d, m), m, d) : "";
      invalidatePostProcessingResults(row);
    }
  }

  void updateRow(int row) {
    var cacheEntry = rowsCache[row];
    if (!cacheEntry) {
      return;
    }

    ensureCellNodesInRowsCache(row);

    var d = getDataItem(row);

    for (var columnIdx in cacheEntry.cellNodesByColumnIdx) {
      if (!cacheEntry.cellNodesByColumnIdx.hasOwnProperty(columnIdx)) {
        continue;
      }

      columnIdx = columnIdx | 0;
      var m = columns[columnIdx],
          node = cacheEntry.cellNodesByColumnIdx[columnIdx];

      if (row == activeRow && columnIdx == activeCell && currentEditor) {
        currentEditor.loadValue(d);
      } else if (d) {
        node.innerHTML = getFormatter(row, m)(row, columnIdx, getDataItemValueForColumn(d, m), m, d);
      } else {
        node.innerHTML = "";
      }
    }

    invalidatePostProcessingResults(row);
  }

  int getViewportHeight() {
    return parseFloat($.css($container.children[0], "height", true)) -
        parseFloat($.css($container.children[0], "paddingTop", true)) -
        parseFloat($.css($container.children[0], "paddingBottom", true)) -
        parseFloat($.css($headerScroller.children[0], "height")) - getVBoxDelta($headerScroller) -
        (options.showTopPanel ? options.topPanelHeight + getVBoxDelta($topPanelScroller) : 0) -
        (options.showHeaderRow ? options.headerRowHeight + getVBoxDelta($headerRowScroller) : 0);
  }

  void resizeCanvas() {
    if (!initialized) { return; }
    if (options.autoHeight) {
      viewportH = options.rowHeight * getDataLengthIncludingAddNew();
    } else {
      viewportH = getViewportHeight();
    }

    numVisibleRows = (viewportH / options.rowHeight).ceil();
    viewportW = parseFloat($.css($container.children[0], "width", true));
    if (!options.autoHeight) {
      $viewport.height(viewportH);
    }

    if (options.forceFitColumns) {
      autosizeColumns();
    }

    updateRowCount();
    handleScroll();
    // Since the width has changed, force the render() to reevaluate virtually rendered cells.
    lastRenderedScrollLeft = -1;
    render();
  }

  void updateRowCount() {
    if (!initialized) { return; }

    var dataLengthIncludingAddNew = getDataLengthIncludingAddNew();
    var numberOfRows = dataLengthIncludingAddNew +
        (options.leaveSpaceForNewRows ? numVisibleRows - 1 : 0);

    var oldViewportHasVScroll = viewportHasVScroll;
    // with autoHeight, we do not need to accommodate the vertical scroll bar
    viewportHasVScroll = !options.autoHeight && (numberOfRows * options.rowHeight > viewportH);

    makeActiveCellNormal();

    // remove the rows that are now outside of the data range
    // this helps avoid redundant calls to .removeRow() when the size of the data decreased by thousands of rows
    var l = dataLengthIncludingAddNew - 1;
    for (var i in rowsCache) {
      if (i >= l) {
        removeRowFromCache(i);
      }
    }

    if (activeCellNode && activeRow > l) {
      resetActiveCell();
    }

    var oldH = h;
    th = math.max(options.rowHeight * numberOfRows, viewportH - scrollbarDimensions.height);
    if (th < maxSupportedCssHeight) {
      // just one page
      h = ph = th;
      n = 1;
      cj = 0;
    } else {
      // break into pages
      h = maxSupportedCssHeight;
      ph = h / 100;
      n = Math.floor(th / ph);
      cj = (th - h) / (n - 1);
    }

    if (h != oldH) {
      $canvas.css("height", h);
      scrollTop = $viewport.children[0].scrollTop;
    }

    var oldScrollTopInRange = (scrollTop + offset <= th - viewportH);

    if (th == 0 || scrollTop == 0) {
      page = offset = 0;
    } else if (oldScrollTopInRange) {
      // maintain virtual position
      scrollTo(scrollTop + offset);
    } else {
      // scroll to bottom
      scrollTo(th - viewportH);
    }

    if (h != oldH && options.autoHeight) {
      resizeCanvas();
    }

    if (options.forceFitColumns && oldViewportHasVScroll != viewportHasVScroll) {
      autosizeColumns();
    }
    updateCanvasWidth(false);
  }

  Map<String, int> getVisibleRange(viewportTop, viewportLeft) {
    if (viewportTop == null) {
      viewportTop = scrollTop;
    }
    if (viewportLeft == null) {
      viewportLeft = scrollLeft;
    }

    return {
      'top': getRowFromPosition(viewportTop),
      'bottom': getRowFromPosition(viewportTop + viewportH) + 1,
      'leftPx': viewportLeft,
      'rightPx': viewportLeft + viewportW
    };
  }

  Range getRenderedRange(int viewportTop, int viewportLeft) {
    var range = getVisibleRange(viewportTop, viewportLeft);
    var buffer = Math.round(viewportH / options.rowHeight);
    var minBuffer = 3;

    if (vScrollDir == -1) {
      range.top -= buffer;
      range.bottom += minBuffer;
    } else if (vScrollDir == 1) {
      range.top -= minBuffer;
      range.bottom += buffer;
    } else {
      range.top -= minBuffer;
      range.bottom += minBuffer;
    }

    range.top = math.max(0, range.top);
    range.bottom = Math.min(getDataLengthIncludingAddNew() - 1, range.bottom);

    range.leftPx -= viewportW;
    range.rightPx += viewportW;

    range.leftPx = Math.max(0, range.leftPx);
    range.rightPx = Math.min(canvasWidth, range.rightPx);

    return range;
  }

  function ensureCellNodesInRowsCache(row) {
    var cacheEntry = rowsCache[row];
    if (cacheEntry) {
      if (cacheEntry.cellRenderQueue.length) {
        var lastChild = cacheEntry.rowNode.lastChild;
        while (cacheEntry.cellRenderQueue.length) {
          var columnIdx = cacheEntry.cellRenderQueue.pop();
          cacheEntry.cellNodesByColumnIdx[columnIdx] = lastChild;
          lastChild = lastChild.previousSibling;
        }
      }
    }
  }

  function cleanUpCells(range, row) {
    var totalCellsRemoved = 0;
    var cacheEntry = rowsCache[row];

    // Remove cells outside the range.
    var cellsToRemove = [];
    for (var i in cacheEntry.cellNodesByColumnIdx) {
      // I really hate it when people mess with Array.prototype.
      if (!cacheEntry.cellNodesByColumnIdx.hasOwnProperty(i)) {
        continue;
      }

      // This is a string, so it needs to be cast back to a number.
      i = i | 0;

      var colspan = cacheEntry.cellColSpans[i];
      if (columnPosLeft[i] > range.rightPx ||
        columnPosRight[Math.min(columns.length - 1, i + colspan - 1)] < range.leftPx) {
        if (!(row == activeRow && i == activeCell)) {
          cellsToRemove.push(i);
        }
      }
    }

    var cellToRemove;
    while ((cellToRemove = cellsToRemove.pop()) != null) {
      cacheEntry.rowNode.removeChild(cacheEntry.cellNodesByColumnIdx[cellToRemove]);
      delete cacheEntry.cellColSpans[cellToRemove];
      delete cacheEntry.cellNodesByColumnIdx[cellToRemove];
      if (postProcessedRows[row]) {
        delete postProcessedRows[row][cellToRemove];
      }
      totalCellsRemoved++;
    }
  }

  function cleanUpAndRenderCells(range) {
    var cacheEntry;
    var stringArray = [];
    var processedRows = [];
    var cellsAdded;
    var totalCellsAdded = 0;
    var colspan;

    for (var row = range.top, btm = range.bottom; row <= btm; row++) {
      cacheEntry = rowsCache[row];
      if (!cacheEntry) {
        continue;
      }

      // cellRenderQueue populated in renderRows() needs to be cleared first
      ensureCellNodesInRowsCache(row);

      cleanUpCells(range, row);

      // Render missing cells.
      cellsAdded = 0;

      var metadata = data.getItemMetadata && data.getItemMetadata(row);
      metadata = metadata && metadata.columns;

      var d = getDataItem(row);

      // TODO:  shorten this loop (index? heuristics? binary search?)
      for (var i = 0, ii = columns.length; i < ii; i++) {
        // Cells to the right are outside the range.
        if (columnPosLeft[i] > range.rightPx) {
          break;
        }

        // Already rendered.
        if ((colspan = cacheEntry.cellColSpans[i]) != null) {
          i += (colspan > 1 ? colspan - 1 : 0);
          continue;
        }

        colspan = 1;
        if (metadata) {
          var columnData = metadata[columns[i].id] || metadata[i];
          colspan = (columnData && columnData.colspan) || 1;
          if (colspan === "*") {
            colspan = ii - i;
          }
        }

        if (columnPosRight[Math.min(ii - 1, i + colspan - 1)] > range.leftPx) {
          appendCellHtml(stringArray, row, i, colspan, d);
          cellsAdded++;
        }

        i += (colspan > 1 ? colspan - 1 : 0);
      }

      if (cellsAdded) {
        totalCellsAdded += cellsAdded;
        processedRows.push(row);
      }
    }

    if (!stringArray.length) {
      return;
    }

    var x = document.createElement("div");
    x.innerHTML = stringArray.join("");

    var processedRow;
    var node;
    while ((processedRow = processedRows.pop()) != null) {
      cacheEntry = rowsCache[processedRow];
      var columnIdx;
      while ((columnIdx = cacheEntry.cellRenderQueue.pop()) != null) {
        node = x.lastChild;
        cacheEntry.rowNode.appendChild(node);
        cacheEntry.cellNodesByColumnIdx[columnIdx] = node;
      }
    }
  }

  function renderRows(range) {
    var parentNode = $canvas[0],
        stringArray = [],
        rows = [],
        needToReselectCell = false,
        dataLength = getDataLength();

    for (var i = range.top, ii = range.bottom; i <= ii; i++) {
      if (rowsCache[i]) {
        continue;
      }
      renderedRows++;
      rows.push(i);

      // Create an entry right away so that appendRowHtml() can
      // start populatating it.
      rowsCache[i] = {
        "rowNode": null,

        // ColSpans of rendered cells (by column idx).
        // Can also be used for checking whether a cell has been rendered.
        "cellColSpans": [],

        // Cell nodes (by column idx).  Lazy-populated by ensureCellNodesInRowsCache().
        "cellNodesByColumnIdx": [],

        // Column indices of cell nodes that have been rendered, but not yet indexed in
        // cellNodesByColumnIdx.  These are in the same order as cell nodes added at the
        // end of the row.
        "cellRenderQueue": []
      };

      appendRowHtml(stringArray, i, range, dataLength);
      if (activeCellNode && activeRow === i) {
        needToReselectCell = true;
      }
      counter_rows_rendered++;
    }

    if (!rows.length) { return; }

    var x = document.createElement("div");
    x.innerHTML = stringArray.join("");

    for (var i = 0, ii = rows.length; i < ii; i++) {
      rowsCache[rows[i]].rowNode = parentNode.appendChild(x.firstChild);
    }

    if (needToReselectCell) {
      activeCellNode = getCellNode(activeRow, activeCell);
    }
  }

  function startPostProcessing() {
    if (!options.enableAsyncPostRender) {
      return;
    }
    clearTimeout(h_postrender);
    h_postrender = setTimeout(asyncPostProcessRows, options.asyncPostRenderDelay);
  }

  function invalidatePostProcessingResults(row) {
    delete postProcessedRows[row];
    postProcessFromRow = Math.min(postProcessFromRow, row);
    postProcessToRow = Math.max(postProcessToRow, row);
    startPostProcessing();
  }

  function updateRowPositions() {
    for (var row in rowsCache) {
      rowsCache[row].rowNode.style.top = getRowTop(row) + "px";
    }
  }

  function render() {
    if (!initialized) { return; }
    var visible = getVisibleRange();
    var rendered = getRenderedRange();

    // remove rows no longer in the viewport
    cleanupRows(rendered);

    // add new rows & missing cells in existing rows
    if (lastRenderedScrollLeft != scrollLeft) {
      cleanUpAndRenderCells(rendered);
    }

    // render missing rows
    renderRows(rendered);

    postProcessFromRow = visible.top;
    postProcessToRow = Math.min(getDataLengthIncludingAddNew() - 1, visible.bottom);
    startPostProcessing();

    lastRenderedScrollTop = scrollTop;
    lastRenderedScrollLeft = scrollLeft;
    h_render = null;
  }

  function handleHeaderRowScroll() {
    var scrollLeft = $headerRowScroller[0].scrollLeft;
    if (scrollLeft != $viewport[0].scrollLeft) {
      $viewport[0].scrollLeft = scrollLeft;
    }
  }

  function handleScroll() {
    scrollTop = $viewport[0].scrollTop;
    scrollLeft = $viewport[0].scrollLeft;
    var vScrollDist = Math.abs(scrollTop - prevScrollTop);
    var hScrollDist = Math.abs(scrollLeft - prevScrollLeft);

    if (hScrollDist) {
      prevScrollLeft = scrollLeft;
      $headerScroller[0].scrollLeft = scrollLeft;
      $topPanelScroller[0].scrollLeft = scrollLeft;
      $headerRowScroller[0].scrollLeft = scrollLeft;
    }

    if (vScrollDist) {
      vScrollDir = prevScrollTop < scrollTop ? 1 : -1;
      prevScrollTop = scrollTop;

      // switch virtual pages if needed
      if (vScrollDist < viewportH) {
        scrollTo(scrollTop + offset);
      } else {
        var oldOffset = offset;
        if (h == viewportH) {
          page = 0;
        } else {
          page = Math.min(n - 1, Math.floor(scrollTop * ((th - viewportH) / (h - viewportH)) * (1 / ph)));
        }
        offset = Math.round(page * cj);
        if (oldOffset != offset) {
          invalidateAllRows();
        }
      }
    }

    if (hScrollDist || vScrollDist) {
      if (h_render) {
        clearTimeout(h_render);
      }

      if (Math.abs(lastRenderedScrollTop - scrollTop) > 20 ||
          Math.abs(lastRenderedScrollLeft - scrollLeft) > 20) {
        if (options.forceSyncScrolling || (
            Math.abs(lastRenderedScrollTop - scrollTop) < viewportH &&
            Math.abs(lastRenderedScrollLeft - scrollLeft) < viewportW)) {
          render();
        } else {
          h_render = setTimeout(render, 50);
        }

        trigger(self.onViewportChanged, {});
      }
    }

    trigger(self.onScroll, {scrollLeft: scrollLeft, scrollTop: scrollTop});
  }

  function asyncPostProcessRows() {
    var dataLength = getDataLength();
    while (postProcessFromRow <= postProcessToRow) {
      var row = (vScrollDir >= 0) ? postProcessFromRow++ : postProcessToRow--;
      var cacheEntry = rowsCache[row];
      if (!cacheEntry || row >= dataLength) {
        continue;
      }

      if (!postProcessedRows[row]) {
        postProcessedRows[row] = {};
      }

      ensureCellNodesInRowsCache(row);
      for (var columnIdx in cacheEntry.cellNodesByColumnIdx) {
        if (!cacheEntry.cellNodesByColumnIdx.hasOwnProperty(columnIdx)) {
          continue;
        }

        columnIdx = columnIdx | 0;

        var m = columns[columnIdx];
        if (m.asyncPostRender && !postProcessedRows[row][columnIdx]) {
          var node = cacheEntry.cellNodesByColumnIdx[columnIdx];
          if (node) {
            m.asyncPostRender(node, row, getDataItem(row), m);
          }
          postProcessedRows[row][columnIdx] = true;
        }
      }

      h_postrender = setTimeout(asyncPostProcessRows, options.asyncPostRenderDelay);
      return;
    }
  }

  function updateCellCssStylesOnRenderedRows(addedHash, removedHash) {
    var node, columnId, addedRowHash, removedRowHash;
    for (var row in rowsCache) {
      removedRowHash = removedHash && removedHash[row];
      addedRowHash = addedHash && addedHash[row];

      if (removedRowHash) {
        for (columnId in removedRowHash) {
          if (!addedRowHash || removedRowHash[columnId] != addedRowHash[columnId]) {
            node = getCellNode(row, getColumnIndex(columnId));
            if (node) {
              $(node).removeClass(removedRowHash[columnId]);
            }
          }
        }
      }

      if (addedRowHash) {
        for (columnId in addedRowHash) {
          if (!removedRowHash || removedRowHash[columnId] != addedRowHash[columnId]) {
            node = getCellNode(row, getColumnIndex(columnId));
            if (node) {
              $(node).addClass(addedRowHash[columnId]);
            }
          }
        }
      }
    }
  }

  function addCellCssStyles(key, hash) {
    if (cellCssClasses[key]) {
      throw "addCellCssStyles: cell CSS hash with key '" + key + "' already exists.";
    }

    cellCssClasses[key] = hash;
    updateCellCssStylesOnRenderedRows(hash, null);

    trigger(self.onCellCssStylesChanged, { "key": key, "hash": hash });
  }

  function removeCellCssStyles(key) {
    if (!cellCssClasses[key]) {
      return;
    }

    updateCellCssStylesOnRenderedRows(null, cellCssClasses[key]);
    delete cellCssClasses[key];

    trigger(self.onCellCssStylesChanged, { "key": key, "hash": null });
  }

  function setCellCssStyles(key, hash) {
    var prevHash = cellCssClasses[key];

    cellCssClasses[key] = hash;
    updateCellCssStylesOnRenderedRows(hash, prevHash);

    trigger(self.onCellCssStylesChanged, { "key": key, "hash": hash });
  }

  function getCellCssStyles(key) {
    return cellCssClasses[key];
  }

  function flashCell(row, cell, speed) {
    speed = speed || 100;
    if (rowsCache[row]) {
      var $cell = $(getCellNode(row, cell));

      function toggleCellClass(times) {
        if (!times) {
          return;
        }
        setTimeout(function () {
              $cell.queue(function () {
                $cell.toggleClass(options.cellFlashingCssClass).dequeue();
                toggleCellClass(times - 1);
              });
            },
            speed);
      }

      toggleCellClass(4);
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////
  // Interactivity

  function handleMouseWheel(e) {
    var rowNode = $(e.target).closest(".slick-row")[0];
    if (rowNode != rowNodeFromLastMouseWheelEvent) {
      if (zombieRowNodeFromLastMouseWheelEvent && zombieRowNodeFromLastMouseWheelEvent != rowNode) {
        $canvas[0].removeChild(zombieRowNodeFromLastMouseWheelEvent);
        zombieRowNodeFromLastMouseWheelEvent = null;
      }
      rowNodeFromLastMouseWheelEvent = rowNode;
    }
  }

  function handleDragInit(e, dd) {
    var cell = getCellFromEvent(e);
    if (!cell || !cellExists(cell.row, cell.cell)) {
      return false;
    }

    var retval = trigger(self.onDragInit, dd, e);
    if (e.isImmediatePropagationStopped()) {
      return retval;
    }

    // if nobody claims to be handling drag'n'drop by stopping immediate propagation,
    // cancel out of it
    return false;
  }

  function handleDragStart(e, dd) {
    var cell = getCellFromEvent(e);
    if (!cell || !cellExists(cell.row, cell.cell)) {
      return false;
    }

    var retval = trigger(self.onDragStart, dd, e);
    if (e.isImmediatePropagationStopped()) {
      return retval;
    }

    return false;
  }

  function handleDrag(e, dd) {
    return trigger(self.onDrag, dd, e);
  }

  function handleDragEnd(e, dd) {
    trigger(self.onDragEnd, dd, e);
  }

  function handleKeyDown(e) {
    trigger(self.onKeyDown, {row: activeRow, cell: activeCell}, e);
    var handled = e.isImmediatePropagationStopped();

    if (!handled) {
      if (!e.shiftKey && !e.altKey && !e.ctrlKey) {
        if (e.which == 27) {
          if (!getEditorLock().isActive()) {
            return; // no editing mode to cancel, allow bubbling and default processing (exit without cancelling the event)
          }
          cancelEditAndSetFocus();
        } else if (e.which == 34) {
          navigatePageDown();
          handled = true;
        } else if (e.which == 33) {
          navigatePageUp();
          handled = true;
        } else if (e.which == 37) {
          handled = navigateLeft();
        } else if (e.which == 39) {
          handled = navigateRight();
        } else if (e.which == 38) {
          handled = navigateUp();
        } else if (e.which == 40) {
          handled = navigateDown();
        } else if (e.which == 9) {
          handled = navigateNext();
        } else if (e.which == 13) {
          if (options.editable) {
            if (currentEditor) {
              // adding new row
              if (activeRow === getDataLength()) {
                navigateDown();
              } else {
                commitEditAndSetFocus();
              }
            } else {
              if (getEditorLock().commitCurrentEdit()) {
                makeActiveCellEditable();
              }
            }
          }
          handled = true;
        }
      } else if (e.which == 9 && e.shiftKey && !e.ctrlKey && !e.altKey) {
        handled = navigatePrev();
      }
    }

    if (handled) {
      // the event has been handled so don't let parent element (bubbling/propagation) or browser (default) handle it
      e.stopPropagation();
      e.preventDefault();
      try {
        e.originalEvent.keyCode = 0; // prevent default behaviour for special keys in IE browsers (F3, F5, etc.)
      }
      // ignore exceptions - setting the original event's keycode throws access denied exception for "Ctrl"
      // (hitting control key only, nothing else), "Shift" (maybe others)
      catch (error) {
      }
    }
  }

  function handleClick(e) {
    if (!currentEditor) {
      // if this click resulted in some cell child node getting focus,
      // don't steal it back - keyboard events will still bubble up
      // IE9+ seems to default DIVs to tabIndex=0 instead of -1, so check for cell clicks directly.
      if (e.target != document.activeElement || $(e.target).hasClass("slick-cell")) {
        setFocus();
      }
    }

    var cell = getCellFromEvent(e);
    if (!cell || (currentEditor !== null && activeRow == cell.row && activeCell == cell.cell)) {
      return;
    }

    trigger(self.onClick, {row: cell.row, cell: cell.cell}, e);
    if (e.isImmediatePropagationStopped()) {
      return;
    }

    if ((activeCell != cell.cell || activeRow != cell.row) && canCellBeActive(cell.row, cell.cell)) {
      if (!getEditorLock().isActive() || getEditorLock().commitCurrentEdit()) {
        scrollRowIntoView(cell.row, false);
        setActiveCellInternal(getCellNode(cell.row, cell.cell));
      }
    }
  }

  function handleContextMenu(e) {
    var $cell = $(e.target).closest(".slick-cell", $canvas);
    if ($cell.length === 0) {
      return;
    }

    // are we editing this cell?
    if (activeCellNode === $cell[0] && currentEditor !== null) {
      return;
    }

    trigger(self.onContextMenu, {}, e);
  }

  function handleDblClick(e) {
    var cell = getCellFromEvent(e);
    if (!cell || (currentEditor !== null && activeRow == cell.row && activeCell == cell.cell)) {
      return;
    }

    trigger(self.onDblClick, {row: cell.row, cell: cell.cell}, e);
    if (e.isImmediatePropagationStopped()) {
      return;
    }

    if (options.editable) {
      gotoCell(cell.row, cell.cell, true);
    }
  }

  function handleHeaderMouseEnter(e) {
    trigger(self.onHeaderMouseEnter, {
      "column": $(this).data("column")
    }, e);
  }

  function handleHeaderMouseLeave(e) {
    trigger(self.onHeaderMouseLeave, {
      "column": $(this).data("column")
    }, e);
  }

  function handleHeaderContextMenu(e) {
    var $header = $(e.target).closest(".slick-header-column", ".slick-header-columns");
    var column = $header && $header.data("column");
    trigger(self.onHeaderContextMenu, {column: column}, e);
  }

  function handleHeaderClick(e) {
    var $header = $(e.target).closest(".slick-header-column", ".slick-header-columns");
    var column = $header && $header.data("column");
    if (column) {
      trigger(self.onHeaderClick, {column: column}, e);
    }
  }

  function handleMouseEnter(e) {
    trigger(self.onMouseEnter, {}, e);
  }

  function handleMouseLeave(e) {
    trigger(self.onMouseLeave, {}, e);
  }

  function cellExists(row, cell) {
    return !(row < 0 || row >= getDataLength() || cell < 0 || cell >= columns.length);
  }

  function getCellFromPoint(x, y) {
    var row = getRowFromPosition(y);
    var cell = 0;

    var w = 0;
    for (var i = 0; i < columns.length && w < x; i++) {
      w += columns[i].width;
      cell++;
    }

    if (cell < 0) {
      cell = 0;
    }

    return {row: row, cell: cell - 1};
  }

  function getCellFromNode(cellNode) {
    // read column number from .l<columnNumber> CSS class
    var cls = /l\d+/.exec(cellNode.className);
    if (!cls) {
      throw "getCellFromNode: cannot get cell - " + cellNode.className;
    }
    return parseInt(cls[0].substr(1, cls[0].length - 1), 10);
  }

  function getRowFromNode(rowNode) {
    for (var row in rowsCache) {
      if (rowsCache[row].rowNode === rowNode) {
        return row | 0;
      }
    }

    return null;
  }

  function getCellFromEvent(e) {
    var $cell = $(e.target).closest(".slick-cell", $canvas);
    if (!$cell.length) {
      return null;
    }

    var row = getRowFromNode($cell[0].parentNode);
    var cell = getCellFromNode($cell[0]);

    if (row == null || cell == null) {
      return null;
    } else {
      return {
        "row": row,
        "cell": cell
      };
    }
  }

  function getCellNodeBox(row, cell) {
    if (!cellExists(row, cell)) {
      return null;
    }

    var y1 = getRowTop(row);
    var y2 = y1 + options.rowHeight - 1;
    var x1 = 0;
    for (var i = 0; i < cell; i++) {
      x1 += columns[i].width;
    }
    var x2 = x1 + columns[cell].width;

    return {
      top: y1,
      left: x1,
      bottom: y2,
      right: x2
    };
  }

  //////////////////////////////////////////////////////////////////////////////////////////////
  // Cell switching

  function resetActiveCell() {
    setActiveCellInternal(null, false);
  }

  function setFocus() {
    if (tabbingDirection == -1) {
      $focusSink[0].focus();
    } else {
      $focusSink2[0].focus();
    }
  }

  function scrollCellIntoView(row, cell, doPaging) {
    scrollRowIntoView(row, doPaging);

    var colspan = getColspan(row, cell);
    var left = columnPosLeft[cell],
      right = columnPosRight[cell + (colspan > 1 ? colspan - 1 : 0)],
      scrollRight = scrollLeft + viewportW;

    if (left < scrollLeft) {
      $viewport.scrollLeft(left);
      handleScroll();
      render();
    } else if (right > scrollRight) {
      $viewport.scrollLeft(Math.min(left, right - $viewport[0].clientWidth));
      handleScroll();
      render();
    }
  }

  function setActiveCellInternal(newCell, opt_editMode) {
    if (activeCellNode !== null) {
      makeActiveCellNormal();
      $(activeCellNode).removeClass("active");
      if (rowsCache[activeRow]) {
        $(rowsCache[activeRow].rowNode).removeClass("active");
      }
    }

    var activeCellChanged = (activeCellNode !== newCell);
    activeCellNode = newCell;

    if (activeCellNode != null) {
      activeRow = getRowFromNode(activeCellNode.parentNode);
      activeCell = activePosX = getCellFromNode(activeCellNode);

      if (opt_editMode == null) {
        opt_editMode = (activeRow == getDataLength()) || options.autoEdit;
      }

      $(activeCellNode).addClass("active");
      $(rowsCache[activeRow].rowNode).addClass("active");

      if (options.editable && opt_editMode && isCellPotentiallyEditable(activeRow, activeCell)) {
        clearTimeout(h_editorLoader);

        if (options.asyncEditorLoading) {
          h_editorLoader = setTimeout(function () {
            makeActiveCellEditable();
          }, options.asyncEditorLoadDelay);
        } else {
          makeActiveCellEditable();
        }
      }
    } else {
      activeRow = activeCell = null;
    }

    if (activeCellChanged) {
      trigger(self.onActiveCellChanged, getActiveCell());
    }
  }

  function clearTextSelection() {
    if (document.selection && document.selection.empty) {
      try {
        //IE fails here if selected element is not in dom
        document.selection.empty();
      } catch (e) { }
    } else if (window.getSelection) {
      var sel = window.getSelection();
      if (sel && sel.removeAllRanges) {
        sel.removeAllRanges();
      }
    }
  }

  function isCellPotentiallyEditable(row, cell) {
    var dataLength = getDataLength();
    // is the data for this row loaded?
    if (row < dataLength && !getDataItem(row)) {
      return false;
    }

    // are we in the Add New row?  can we create new from this cell?
    if (columns[cell].cannotTriggerInsert && row >= dataLength) {
      return false;
    }

    // does this cell have an editor?
    if (!getEditor(row, cell)) {
      return false;
    }

    return true;
  }

  function makeActiveCellNormal() {
    if (!currentEditor) {
      return;
    }
    trigger(self.onBeforeCellEditorDestroy, {editor: currentEditor});
    currentEditor.destroy();
    currentEditor = null;

    if (activeCellNode) {
      var d = getDataItem(activeRow);
      $(activeCellNode).removeClass("editable invalid");
      if (d) {
        var column = columns[activeCell];
        var formatter = getFormatter(activeRow, column);
        activeCellNode.innerHTML = formatter(activeRow, activeCell, getDataItemValueForColumn(d, column), column, d);
        invalidatePostProcessingResults(activeRow);
      }
    }

    // if there previously was text selected on a page (such as selected text in the edit cell just removed),
    // IE can't set focus to anything else correctly
    if (navigator.userAgent.toLowerCase().match(/msie/)) {
      clearTextSelection();
    }

    getEditorLock().deactivate(editController);
  }

  function makeActiveCellEditable(editor) {
    if (!activeCellNode) {
      return;
    }
    if (!options.editable) {
      throw "Grid : makeActiveCellEditable : should never get called when options.editable is false";
    }

    // cancel pending async call if there is one
    clearTimeout(h_editorLoader);

    if (!isCellPotentiallyEditable(activeRow, activeCell)) {
      return;
    }

    var columnDef = columns[activeCell];
    var item = getDataItem(activeRow);

    if (trigger(self.onBeforeEditCell, {row: activeRow, cell: activeCell, item: item, column: columnDef}) === false) {
      setFocus();
      return;
    }

    getEditorLock().activate(editController);
    $(activeCellNode).addClass("editable");

    // don't clear the cell if a custom editor is passed through
    if (!editor) {
      activeCellNode.innerHTML = "";
    }

    currentEditor = new (editor || getEditor(activeRow, activeCell))({
      grid: self,
      gridPosition: absBox($container[0]),
      position: absBox(activeCellNode),
      container: activeCellNode,
      column: columnDef,
      item: item || {},
      commitChanges: commitEditAndSetFocus,
      cancelChanges: cancelEditAndSetFocus
    });

    if (item) {
      currentEditor.loadValue(item);
    }

    serializedEditorValue = currentEditor.serializeValue();

    if (currentEditor.position) {
      handleActiveCellPositionChange();
    }
  }

  function commitEditAndSetFocus() {
    // if the commit fails, it would do so due to a validation error
    // if so, do not steal the focus from the editor
    if (getEditorLock().commitCurrentEdit()) {
      setFocus();
      if (options.autoEdit) {
        navigateDown();
      }
    }
  }

  function cancelEditAndSetFocus() {
    if (getEditorLock().cancelCurrentEdit()) {
      setFocus();
    }
  }

  function absBox(elem) {
    var box = {
      top: elem.offsetTop,
      left: elem.offsetLeft,
      bottom: 0,
      right: 0,
      width: $(elem).outerWidth(),
      height: $(elem).outerHeight(),
      visible: true};
    box.bottom = box.top + box.height;
    box.right = box.left + box.width;

    // walk up the tree
    var offsetParent = elem.offsetParent;
    while ((elem = elem.parentNode) != document.body) {
      if (box.visible && elem.scrollHeight != elem.offsetHeight && $(elem).css("overflowY") != "visible") {
        box.visible = box.bottom > elem.scrollTop && box.top < elem.scrollTop + elem.clientHeight;
      }

      if (box.visible && elem.scrollWidth != elem.offsetWidth && $(elem).css("overflowX") != "visible") {
        box.visible = box.right > elem.scrollLeft && box.left < elem.scrollLeft + elem.clientWidth;
      }

      box.left -= elem.scrollLeft;
      box.top -= elem.scrollTop;

      if (elem === offsetParent) {
        box.left += elem.offsetLeft;
        box.top += elem.offsetTop;
        offsetParent = elem.offsetParent;
      }

      box.bottom = box.top + box.height;
      box.right = box.left + box.width;
    }

    return box;
  }

  function getActiveCellPosition() {
    return absBox(activeCellNode);
  }

  function getGridPosition() {
    return absBox($container[0])
  }

  function handleActiveCellPositionChange() {
    if (!activeCellNode) {
      return;
    }

    trigger(self.onActiveCellPositionChanged, {});

    if (currentEditor) {
      var cellBox = getActiveCellPosition();
      if (currentEditor.show && currentEditor.hide) {
        if (!cellBox.visible) {
          currentEditor.hide();
        } else {
          currentEditor.show();
        }
      }

      if (currentEditor.position) {
        currentEditor.position(cellBox);
      }
    }
  }

  function getCellEditor() {
    return currentEditor;
  }

  function getActiveCell() {
    if (!activeCellNode) {
      return null;
    } else {
      return {row: activeRow, cell: activeCell};
    }
  }

  function getActiveCellNode() {
    return activeCellNode;
  }

  function scrollRowIntoView(row, doPaging) {
    var rowAtTop = row * options.rowHeight;
    var rowAtBottom = (row + 1) * options.rowHeight - viewportH + (viewportHasHScroll ? scrollbarDimensions.height : 0);

    // need to page down?
    if ((row + 1) * options.rowHeight > scrollTop + viewportH + offset) {
      scrollTo(doPaging ? rowAtTop : rowAtBottom);
      render();
    }
    // or page up?
    else if (row * options.rowHeight < scrollTop + offset) {
      scrollTo(doPaging ? rowAtBottom : rowAtTop);
      render();
    }
  }

  function scrollRowToTop(row) {
    scrollTo(row * options.rowHeight);
    render();
  }

  function scrollPage(dir) {
    var deltaRows = dir * numVisibleRows;
    scrollTo((getRowFromPosition(scrollTop) + deltaRows) * options.rowHeight);
    render();

    if (options.enableCellNavigation && activeRow != null) {
      var row = activeRow + deltaRows;
      var dataLengthIncludingAddNew = getDataLengthIncludingAddNew();
      if (row >= dataLengthIncludingAddNew) {
        row = dataLengthIncludingAddNew - 1;
      }
      if (row < 0) {
        row = 0;
      }

      var cell = 0, prevCell = null;
      var prevActivePosX = activePosX;
      while (cell <= activePosX) {
        if (canCellBeActive(row, cell)) {
          prevCell = cell;
        }
        cell += getColspan(row, cell);
      }

      if (prevCell !== null) {
        setActiveCellInternal(getCellNode(row, prevCell));
        activePosX = prevActivePosX;
      } else {
        resetActiveCell();
      }
    }
  }

  function navigatePageDown() {
    scrollPage(1);
  }

  function navigatePageUp() {
    scrollPage(-1);
  }

  function getColspan(row, cell) {
    var metadata = data.getItemMetadata && data.getItemMetadata(row);
    if (!metadata || !metadata.columns) {
      return 1;
    }

    var columnData = metadata.columns[columns[cell].id] || metadata.columns[cell];
    var colspan = (columnData && columnData.colspan);
    if (colspan === "*") {
      colspan = columns.length - cell;
    } else {
      colspan = colspan || 1;
    }

    return colspan;
  }

  function findFirstFocusableCell(row) {
    var cell = 0;
    while (cell < columns.length) {
      if (canCellBeActive(row, cell)) {
        return cell;
      }
      cell += getColspan(row, cell);
    }
    return null;
  }

  function findLastFocusableCell(row) {
    var cell = 0;
    var lastFocusableCell = null;
    while (cell < columns.length) {
      if (canCellBeActive(row, cell)) {
        lastFocusableCell = cell;
      }
      cell += getColspan(row, cell);
    }
    return lastFocusableCell;
  }

  function gotoRight(row, cell, posX) {
    if (cell >= columns.length) {
      return null;
    }

    do {
      cell += getColspan(row, cell);
    }
    while (cell < columns.length && !canCellBeActive(row, cell));

    if (cell < columns.length) {
      return {
        "row": row,
        "cell": cell,
        "posX": cell
      };
    }
    return null;
  }

  function gotoLeft(row, cell, posX) {
    if (cell <= 0) {
      return null;
    }

    var firstFocusableCell = findFirstFocusableCell(row);
    if (firstFocusableCell === null || firstFocusableCell >= cell) {
      return null;
    }

    var prev = {
      "row": row,
      "cell": firstFocusableCell,
      "posX": firstFocusableCell
    };
    var pos;
    while (true) {
      pos = gotoRight(prev.row, prev.cell, prev.posX);
      if (!pos) {
        return null;
      }
      if (pos.cell >= cell) {
        return prev;
      }
      prev = pos;
    }
  }

  function gotoDown(row, cell, posX) {
    var prevCell;
    var dataLengthIncludingAddNew = getDataLengthIncludingAddNew();
    while (true) {
      if (++row >= dataLengthIncludingAddNew) {
        return null;
      }

      prevCell = cell = 0;
      while (cell <= posX) {
        prevCell = cell;
        cell += getColspan(row, cell);
      }

      if (canCellBeActive(row, prevCell)) {
        return {
          "row": row,
          "cell": prevCell,
          "posX": posX
        };
      }
    }
  }

  function gotoUp(row, cell, posX) {
    var prevCell;
    while (true) {
      if (--row < 0) {
        return null;
      }

      prevCell = cell = 0;
      while (cell <= posX) {
        prevCell = cell;
        cell += getColspan(row, cell);
      }

      if (canCellBeActive(row, prevCell)) {
        return {
          "row": row,
          "cell": prevCell,
          "posX": posX
        };
      }
    }
  }

  function gotoNext(row, cell, posX) {
    if (row == null && cell == null) {
      row = cell = posX = 0;
      if (canCellBeActive(row, cell)) {
        return {
          "row": row,
          "cell": cell,
          "posX": cell
        };
      }
    }

    var pos = gotoRight(row, cell, posX);
    if (pos) {
      return pos;
    }

    var firstFocusableCell = null;
    var dataLengthIncludingAddNew = getDataLengthIncludingAddNew();
    while (++row < dataLengthIncludingAddNew) {
      firstFocusableCell = findFirstFocusableCell(row);
      if (firstFocusableCell !== null) {
        return {
          "row": row,
          "cell": firstFocusableCell,
          "posX": firstFocusableCell
        };
      }
    }
    return null;
  }

  function gotoPrev(row, cell, posX) {
    if (row == null && cell == null) {
      row = getDataLengthIncludingAddNew() - 1;
      cell = posX = columns.length - 1;
      if (canCellBeActive(row, cell)) {
        return {
          "row": row,
          "cell": cell,
          "posX": cell
        };
      }
    }

    var pos;
    var lastSelectableCell;
    while (!pos) {
      pos = gotoLeft(row, cell, posX);
      if (pos) {
        break;
      }
      if (--row < 0) {
        return null;
      }

      cell = 0;
      lastSelectableCell = findLastFocusableCell(row);
      if (lastSelectableCell !== null) {
        pos = {
          "row": row,
          "cell": lastSelectableCell,
          "posX": lastSelectableCell
        };
      }
    }
    return pos;
  }

  function navigateRight() {
    return navigate("right");
  }

  function navigateLeft() {
    return navigate("left");
  }

  function navigateDown() {
    return navigate("down");
  }

  function navigateUp() {
    return navigate("up");
  }

  function navigateNext() {
    return navigate("next");
  }

  function navigatePrev() {
    return navigate("prev");
  }

  /**
   * @param {string} dir Navigation direction.
   * @return {boolean} Whether navigation resulted in a change of active cell.
   */
  function navigate(dir) {
    if (!options.enableCellNavigation) {
      return false;
    }

    if (!activeCellNode && dir != "prev" && dir != "next") {
      return false;
    }

    if (!getEditorLock().commitCurrentEdit()) {
      return true;
    }
    setFocus();

    var tabbingDirections = {
      "up": -1,
      "down": 1,
      "left": -1,
      "right": 1,
      "prev": -1,
      "next": 1
    };
    tabbingDirection = tabbingDirections[dir];

    var stepFunctions = {
      "up": gotoUp,
      "down": gotoDown,
      "left": gotoLeft,
      "right": gotoRight,
      "prev": gotoPrev,
      "next": gotoNext
    };
    var stepFn = stepFunctions[dir];
    var pos = stepFn(activeRow, activeCell, activePosX);
    if (pos) {
      var isAddNewRow = (pos.row == getDataLength());
      scrollCellIntoView(pos.row, pos.cell, !isAddNewRow);
      setActiveCellInternal(getCellNode(pos.row, pos.cell));
      activePosX = pos.posX;
      return true;
    } else {
      setActiveCellInternal(getCellNode(activeRow, activeCell));
      return false;
    }
  }

  function getCellNode(row, cell) {
    if (rowsCache[row]) {
      ensureCellNodesInRowsCache(row);
      return rowsCache[row].cellNodesByColumnIdx[cell];
    }
    return null;
  }

  function setActiveCell(row, cell) {
    if (!initialized) { return; }
    if (row > getDataLength() || row < 0 || cell >= columns.length || cell < 0) {
      return;
    }

    if (!options.enableCellNavigation) {
      return;
    }

    scrollCellIntoView(row, cell, false);
    setActiveCellInternal(getCellNode(row, cell), false);
  }

  function canCellBeActive(row, cell) {
    if (!options.enableCellNavigation || row >= getDataLengthIncludingAddNew() ||
        row < 0 || cell >= columns.length || cell < 0) {
      return false;
    }

    var rowMetadata = data.getItemMetadata && data.getItemMetadata(row);
    if (rowMetadata && typeof rowMetadata.focusable === "boolean") {
      return rowMetadata.focusable;
    }

    var columnMetadata = rowMetadata && rowMetadata.columns;
    if (columnMetadata && columnMetadata[columns[cell].id] && typeof columnMetadata[columns[cell].id].focusable === "boolean") {
      return columnMetadata[columns[cell].id].focusable;
    }
    if (columnMetadata && columnMetadata[cell] && typeof columnMetadata[cell].focusable === "boolean") {
      return columnMetadata[cell].focusable;
    }

    return columns[cell].focusable;
  }

  function canCellBeSelected(row, cell) {
    if (row >= getDataLength() || row < 0 || cell >= columns.length || cell < 0) {
      return false;
    }

    var rowMetadata = data.getItemMetadata && data.getItemMetadata(row);
    if (rowMetadata && typeof rowMetadata.selectable === "boolean") {
      return rowMetadata.selectable;
    }

    var columnMetadata = rowMetadata && rowMetadata.columns && (rowMetadata.columns[columns[cell].id] || rowMetadata.columns[cell]);
    if (columnMetadata && typeof columnMetadata.selectable === "boolean") {
      return columnMetadata.selectable;
    }

    return columns[cell].selectable;
  }

  function gotoCell(row, cell, forceEdit) {
    if (!initialized) { return; }
    if (!canCellBeActive(row, cell)) {
      return;
    }

    if (!getEditorLock().commitCurrentEdit()) {
      return;
    }

    scrollCellIntoView(row, cell, false);

    var newCell = getCellNode(row, cell);

    // if selecting the 'add new' row, start editing right away
    setActiveCellInternal(newCell, forceEdit || (row === getDataLength()) || options.autoEdit);

    // if no editor was created, set the focus back on the grid
    if (!currentEditor) {
      setFocus();
    }
  }


  //////////////////////////////////////////////////////////////////////////////////////////////
  // IEditor implementation for the editor lock

  function commitCurrentEdit() {
    var item = getDataItem(activeRow);
    var column = columns[activeCell];

    if (currentEditor) {
      if (currentEditor.isValueChanged()) {
        var validationResults = currentEditor.validate();

        if (validationResults.valid) {
          if (activeRow < getDataLength()) {
            var editCommand = {
              row: activeRow,
              cell: activeCell,
              editor: currentEditor,
              serializedValue: currentEditor.serializeValue(),
              prevSerializedValue: serializedEditorValue,
              execute: function () {
                this.editor.applyValue(item, this.serializedValue);
                updateRow(this.row);
                trigger(self.onCellChange, {
                  row: activeRow,
                  cell: activeCell,
                  item: item
                });
              },
              undo: function () {
                this.editor.applyValue(item, this.prevSerializedValue);
                updateRow(this.row);
                trigger(self.onCellChange, {
                  row: activeRow,
                  cell: activeCell,
                  item: item
                });
              }
            };

            if (options.editCommandHandler) {
              makeActiveCellNormal();
              options.editCommandHandler(item, column, editCommand);
            } else {
              editCommand.execute();
              makeActiveCellNormal();
            }

          } else {
            var newItem = {};
            currentEditor.applyValue(newItem, currentEditor.serializeValue());
            makeActiveCellNormal();
            trigger(self.onAddNewRow, {item: newItem, column: column});
          }

          // check whether the lock has been re-acquired by event handlers
          return !getEditorLock().isActive();
        } else {
          // Re-add the CSS class to trigger transitions, if any.
          $(activeCellNode).removeClass("invalid");
          $(activeCellNode).width();  // force layout
          $(activeCellNode).addClass("invalid");

          trigger(self.onValidationError, {
            editor: currentEditor,
            cellNode: activeCellNode,
            validationResults: validationResults,
            row: activeRow,
            cell: activeCell,
            column: column
          });

          currentEditor.focus();
          return false;
        }
      }

      makeActiveCellNormal();
    }
    return true;
  }

  function cancelCurrentEdit() {
    makeActiveCellNormal();
    return true;
  }

  function rowsToRanges(rows) {
    var ranges = [];
    var lastCell = columns.length - 1;
    for (var i = 0; i < rows.length; i++) {
      ranges.push(new Slick.Range(rows[i], 0, rows[i], lastCell));
    }
    return ranges;
  }

  function getSelectedRows() {
    if (!selectionModel) {
      throw "Selection model is not set";
    }
    return selectedRows;
  }

  function setSelectedRows(rows) {
    if (!selectionModel) {
      throw "Selection model is not set";
    }
    selectionModel.setSelectedRanges(rowsToRanges(rows));
  }


  //////////////////////////////////////////////////////////////////////////////////////////////
  // Debug

  this.debug = function () {
    var s = "";

    s += ("\n" + "counter_rows_rendered:  " + counter_rows_rendered);
    s += ("\n" + "counter_rows_removed:  " + counter_rows_removed);
    s += ("\n" + "renderedRows:  " + renderedRows);
    s += ("\n" + "numVisibleRows:  " + numVisibleRows);
    s += ("\n" + "maxSupportedCssHeight:  " + maxSupportedCssHeight);
    s += ("\n" + "n(umber of pages):  " + n);
    s += ("\n" + "(current) page:  " + page);
    s += ("\n" + "page height (ph):  " + ph);
    s += ("\n" + "vScrollDir:  " + vScrollDir);

    alert(s);
  };

  // a debug helper to be able to access private members
//    this.eval = function (expr) {
//      return eval(expr);
//    };

  //////////////////////////////////////////////////////////////////////////////////////////////
  // Public API

//    $.extend(this, {
//      "slickGridVersion": "2.1",

    // Events
//      "onScroll": new Slick.Event(),
//      "onSort": new Slick.Event(),
//      "onHeaderMouseEnter": new Slick.Event(),
//      "onHeaderMouseLeave": new Slick.Event(),
//      "onHeaderContextMenu": new Slick.Event(),
//      "onHeaderClick": new Slick.Event(),
//      "onHeaderCellRendered": new Slick.Event(),
//      "onBeforeHeaderCellDestroy": new Slick.Event(),
//      "onHeaderRowCellRendered": new Slick.Event(),
//      "onBeforeHeaderRowCellDestroy": new Slick.Event(),
//      "onMouseEnter": new Slick.Event(),
//      "onMouseLeave": new Slick.Event(),
//      "onClick": new Slick.Event(),
//      "onDblClick": new Slick.Event(),
//      "onContextMenu": new Slick.Event(),
//      "onKeyDown": new Slick.Event(),
//      "onAddNewRow": new Slick.Event(),
//      "onValidationError": new Slick.Event(),
//      "onViewportChanged": new Slick.Event(),
//      "onColumnsReordered": new Slick.Event(),
//      "onColumnsResized": new Slick.Event(),
//      "onCellChange": new Slick.Event(),
//      "onBeforeEditCell": new Slick.Event(),
//      "onBeforeCellEditorDestroy": new Slick.Event(),
//      "onBeforeDestroy": new Slick.Event(),
//      "onActiveCellChanged": new Slick.Event(),
//      "onActiveCellPositionChanged": new Slick.Event(),
//      "onDragInit": new Slick.Event(),
//      "onDragStart": new Slick.Event(),
//      "onDrag": new Slick.Event(),
//      "onDragEnd": new Slick.Event(),
//      "onSelectedRowsChanged": new Slick.Event(),
//      "onCellCssStylesChanged": new Slick.Event(),

    // Methods
//      "registerPlugin": registerPlugin,
//      "unregisterPlugin": unregisterPlugin,
//      "getColumns": getColumns,
//      "setColumns": setColumns,
//      "getColumnIndex": getColumnIndex,
//      "updateColumnHeader": updateColumnHeader,
//      "setSortColumn": setSortColumn,
//      "setSortColumns": setSortColumns,
//      "getSortColumns": getSortColumns,
//      "autosizeColumns": autosizeColumns,
//      "getOptions": getOptions,
//      "setOptions": setOptions,
//      "getData": getData,
//      "getDataLength": getDataLength,
//      "getDataItem": getDataItem,
//      "setData": setData,
//      "getSelectionModel": getSelectionModel,
//      "setSelectionModel": setSelectionModel,
//      "getSelectedRows": getSelectedRows,
//      "setSelectedRows": setSelectedRows,
//      "getContainerNode": getContainerNode,
//
//      "render": render,
//      "invalidate": invalidate,
//      "invalidateRow": invalidateRow,
//      "invalidateRows": invalidateRows,
//      "invalidateAllRows": invalidateAllRows,
//      "updateCell": updateCell,
//      "updateRow": updateRow,
//      "getViewport": getVisibleRange,
//      "getRenderedRange": getRenderedRange,
//      "resizeCanvas": resizeCanvas,
//      "updateRowCount": updateRowCount,
//      "scrollRowIntoView": scrollRowIntoView,
//      "scrollRowToTop": scrollRowToTop,
//      "scrollCellIntoView": scrollCellIntoView,
//      "getCanvasNode": getCanvasNode,
//      "focus": setFocus,
//
//      "getCellFromPoint": getCellFromPoint,
//      "getCellFromEvent": getCellFromEvent,
//      "getActiveCell": getActiveCell,
//      "setActiveCell": setActiveCell,
//      "getActiveCellNode": getActiveCellNode,
//      "getActiveCellPosition": getActiveCellPosition,
//      "resetActiveCell": resetActiveCell,
//      "editActiveCell": makeActiveCellEditable,
//      "getCellEditor": getCellEditor,
//      "getCellNode": getCellNode,
//      "getCellNodeBox": getCellNodeBox,
//      "canCellBeSelected": canCellBeSelected,
//      "canCellBeActive": canCellBeActive,
//      "navigatePrev": navigatePrev,
//      "navigateNext": navigateNext,
//      "navigateUp": navigateUp,
//      "navigateDown": navigateDown,
//      "navigateLeft": navigateLeft,
//      "navigateRight": navigateRight,
//      "navigatePageUp": navigatePageUp,
//      "navigatePageDown": navigatePageDown,
//      "gotoCell": gotoCell,
//      "getTopPanel": getTopPanel,
//      "setTopPanelVisibility": setTopPanelVisibility,
//      "setHeaderRowVisibility": setHeaderRowVisibility,
//      "getHeaderRow": getHeaderRow,
//      "getHeaderRowColumn": getHeaderRowColumn,
//      "getGridPosition": getGridPosition,
//      "flashCell": flashCell,
//      "addCellCssStyles": addCellCssStyles,
//      "setCellCssStyles": setCellCssStyles,
//      "removeCellCssStyles": removeCellCssStyles,
//      "getCellCssStyles": getCellCssStyles,
//
//      "init": finishInitialization,
//      "destroy": destroy,
//
//      // IEditor implementation
//      "getEditorLock": getEditorLock,
//      "getEditController": getEditController
  });
}

}
