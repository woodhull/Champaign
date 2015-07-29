var WidgetsBox = React.createClass({
  mixins: [FluxMixin, StoreWatchMixin("WidgetsStore")],

  getInitialState() {
    return { widgets: [] };
  },

 getStateFromFlux: function() {
    var store = this.getFlux().store("WidgetsStore");

    return {
      data: store.widgets
    };
  },

  componentDidMount: function() {
    this.getFlux().actions.loadWidgets();
  },

  handleWidgetSubmit(data) {
    this.getFlux().actions.updateWidget(data);
  },

  render() {
    return (
      <div className='widgets'>
        <Widgets onWidgetSubmit={this.handleWidgetSubmit} widgets={this.state.data} campaign_page_id={ this.props.campaign_page_id } />
      </div>
    )
  }
})

var Widgets = React.createClass({

  propTypes: {
    widgets:          React.PropTypes.array.isRequired,
    onWidgetSubmit:   React.PropTypes.func.isRequired,
    campaign_page_id: React.PropTypes.number.isRequired
  },

  render(){
    var widgets = this.props.widgets.map(widget => {
      switch (widget.type) {
        case "TextBodyWidget":
          return (<TextBodyWidget {...widget} onWidgetSubmit={this.props.onWidgetSubmit}></TextBodyWidget>)
        case "RawHtmlWidget":
          return (<RawHtmlWidget {...widget} onWidgetSubmit={this.props.onWidgetSubmit}></RawHtmlWidget>)
        default:
          break;
      }
    })

    return (
      <div className="widgets">
        { widgets }
      </div>
    )
  }
});

$(function(){
  React.render(<WidgetsBox flux={flux} campaign_page_id={window.campaign_page_id} />, document.getElementById("widgets"));
});
