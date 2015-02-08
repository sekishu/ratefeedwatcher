$(function(){
    ws = new WebSocket("ws://websockethost/");
    ws.onmessage = function(evt) {
        $("#msg").html("<p>"+evt.data+"</p>");
    };

    ws.onclose = function() {
        console.log("閉じたよ")
    };

    ws.onopen = function() {
    };
    $("#yyyymmddhhmmss").keypress(function(e){
        if(e.keyCode ==13){
            var val = $("#yyyymmddhhmmss").val()
            ws.send("starttime="+val)
            $("#yyyymmddhhmmss").val("")
        }
    });
    $("#speed").change(function(e){
       var val = document.getElementById("speed").value;
       ws.send("speed="+val)
    });
    $("#meigara").change(function(e){
       var val = document.getElementById("meigara").value;
       ws.send("meigara="+val)
    });
});
