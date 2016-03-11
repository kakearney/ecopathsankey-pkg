// This function creates a Sankey diagram of the biomass fluxes in a food web,
// based on an underlying Ecopath food web model. The code is based on Denes
// Csala's food.js example (MIT License 2014 Denes Csala http://www.csaladen.es)
// and relies on his modified sankey.js code (allowing for reverse links).
//
// This code is intended to be called in the following format:
//
// d3.json("filename.json", function(data) { 
//    d3.select("#targetchart")
// 		.datum(data) 
//     .call(ecopathSankeyChart()); 
// });
//
// where filename.json is a JSON file produced by ecopathsankey.m, and 
// targetchart is the ID of the DOM object to which the diagram with be added.
// Changes to the chart properties can be chained to the call as follows:
//
// d3.json("filename.json", function(data) { 
//    d3.select("#targetchart")
// 		.datum(data) 
//     .call(ecopathSankeyChart()
//        .padding(30)
// 		  .width(400));
// });


// Copyright 2015 Kelly Kearney 


function ecopathSankeyChart() {
    
    // Default values basic chart properties
    
    var margin = {
            top: 10,
            right: 10,
            bottom: 50,
            left: 10
        },
        width = 760,
        height = 400,
        padding = 28,
        lowopacity = 0.3,
        highopacity = 0.7,
        nodewidth = 15;
        
    // Formatting for various types of text, plus default colors
        
    var formatNum = d3.format(".3g"),
        formatFlux = function(a) {
            return formatNum(a) + " t ww/km²/yr"
        },
        formatMass = function(a) {
            return formatNum(a) + " t ww/km²"
        },
        formatRate = function(a) {
            return formatNum(a) + " /yr"
        },
        formatNone = function(a) {
            return formatNum(a)
        },
        color = d3.scale.category20();
        
        
    // Function to create chart 
        
    function chart(selection) {
        selection.each(function(d, i) {
            
            // Add svg canvas to chart

            var svg = d3.select(this).append("svg")
             	.attr("width", width + margin.left + margin.right)
             	.attr("height", height + margin.top + margin.bottom)
              	  .append("g")
             	.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
           
            // Create sankey

            var sankey = d3.sankey()
             .nodeWidth(nodewidth)
             .nodePadding(padding)
             .size([width, height])
             .nodes(d.nodes)
             .links(d.links)
             .layout(500);

            var path = sankey.reversibleLink();

            // Add links, along with reversible-link pathways

            var g = svg.append("g") //link
             .selectAll(".link")
                 .data(d.links)
             .enter().append("g")
                 .attr("class", "link")
                 .sort(function(j, i) {return i.dy - j.dy});

            var h = g.append("path") //path0
             .attr("d", path(0));
            var f = g.append("path") //path1
             .attr("d", path(1));
            var e = g.append("path") //path2
             .attr("d", path(2));

            // Link properties:
            // - color links according to source node
            // - increase opacity on mouseover
            // - hover text lists flux between source and sink nodes, based on Q data

            g.attr("fill", function(i) {
                 return i.source.color = color(i.source.name.replace(/ .*/, ""))
             }).attr("opacity", lowopacity).on("mouseover", function(d) {
                 d3.select(this).style('opacity', highopacity);
             }).on("mouseout", function(d) {
                 d3.select(this).style('opacity', lowopacity);
             }).append("title") //link
             .text(function(i) {
                 return i.source.name + " → " + i.target.name + "\n" + formatFlux(i.Q)
             });

             // Add nodes

            var c = svg.append("g") //node
             .selectAll(".node")
                 .data(d.nodes)
             .enter().append("g")
                 .attr("class", "node")
                 .attr("transform", function(i) {return "translate(" + i.x + "," + i.y + ")"})
                 .call(d3.behavior.drag().origin(function(i) {return i})
                 .on("dragstart", function() {this.parentNode.appendChild(this)})
                 .on("drag", dragnode));

            // Node properties:
            // - height based on flux
            // - color somehow associated with horizontal location?
            // - on mouseover, increase opacity of source and sink nodes
            // - on doubleclick, show only links where node is source, not sink
            // - hover text lists Ecopath variables, base on B, PB, QB, and EE data in file

            c.append("rect") //node
             .attr("height", function(i) {return i.dy})
             .attr("width", sankey.nodeWidth()).style("fill", function(i) {
                                     return i.color = color(i.name.replace(/ .*/, ""))
                                     })
             .style("stroke", function(i) {return d3.rgb(i.color).darker(2)})
                .on("mouseover", function(d) {
                 svg.selectAll(".link").filter(function(l) {
                     return l.source == d || l.target == d;
                 }).transition().style('opacity', highopacity);
             })
             .on("mouseout", function(d) {
                 svg.selectAll(".link").filter(function(l) {
                     return l.source == d || l.target == d;
                 }).transition().style('opacity', lowopacity);
             })
             .on("dblclick", function(d) {
                 svg.selectAll(".link").filter(function(l) {
                     return l.target !== d && l.source !==d;
                 }).attr("display", function() {
                     if (d3.select(this).attr("display") == "none") return "inline"
                     else return "none"
                 });
             })
             .append("title").text(function(i) {
                 return i.name + "\nB: " + formatMass(i.B) + "\nPB: " + formatRate(i.PB) + "\nQB: " + formatRate(i.QB)  + "\nEE: " + formatNone(i.EE) + "\nTL: " + formatNone(i.TLf)
             });

            // Add text labels to nodes
            // Group name to the either the right or left of the node 
			// (can create a lot of overlap, but easiest way to keep on canvas)
			 
            c.append("text") //node
             .attr("x", -6)
			 .attr("y", function(i) {return i.dy / 2})
			 .attr("dy", ".35em")
			 .attr("text-anchor", "end")
			 .attr("transform", null)
			 .text(function(i) {return i.name})
			 .filter(function(i) {return i.x < width / 2})
			 	.attr("x", 6 + sankey.nodeWidth())
			 	.attr("text-anchor", "start")


            // Trophic level axis

            var tlmax = d3.max(d.nodes, function(x) {return x.TLr;})

            var tlmin = d3.min(d.nodes, function(x) {return x.TLr;})

            var tl = d3.scale.linear()
             .range([0,width])
             .domain([tlmin,tlmax]);
            var xAxis = d3.svg.axis()
                .scale(tl)
                .orient("bottom");

            var xAxisGroup = svg.append("g")
                 .attr("class","axis")
                 .attr("transform", "translate(0," + (height + 15) + ")")
                             .call(xAxis);
							 
		    function dragnode(i) { // dragmove: Allow movement in y-direction, but not x
		    	d3.select(this).attr("transform", "translate(" + i.x + "," + (i.y = Math.max(0, Math.min(height - i.dy, d3.event.y))) + ")")
		        sankey.relayout();
		        f.attr("d", path(1));
		        h.attr("d", path(0));
		        e.attr("d", path(2))
		    };
            
            
        });
        
        
    }
	
    // Getter-setters to fill in user-set variables
    
    chart.margin = function(value) {
        if (!arguments.length) return margin;
        margin = value;
        return chart;
    };
    
    chart.width = function(value) {
        if (!arguments.length) return width;
        width = value;
        return chart;
    };
    
    chart.height = function(value) {
        if (!arguments.length) return height;
        height = value;
        return chart;
    };
    
    chart.padding = function(value) {
        if (!arguments.length) return padding;
        padding = value;
        return chart;
    };
    
    chart.lowopacity = function(value) {
        if (!arguments.length) return lowopacity;
        lowopacity = value;
        return chart;
    };
    
    chart.highopacity = function(value) {
        if (!arguments.length) return highopacity;
        highopacity = value;
        return chart;
    };
    
    chart.nodewidth = function(value) {
        if (!arguments.length) return nodewidth;
        nodewidth = value;
        return chart;
    };
    
    return chart;
        
}