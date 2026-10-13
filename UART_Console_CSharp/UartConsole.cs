using System;
using System.Drawing;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

public sealed class UartConsole : Form
{
    readonly ComboBox port = SelectBox(new string[0], "", 100);
    readonly ComboBox baud = SelectBox(new[] {"2400","4800","9600","19200","38400","57600","76800","115200","230400"}, "115200", 100);
    readonly ComboBox bits = SelectBox(new[] {"5","6","7","8"}, "8", 65);
    readonly ComboBox parity = SelectBox(new[] {"None","Odd","Even"}, "None", 85);
    readonly ComboBox stop = SelectBox(new[] {"1","2"}, "1", 65);
    readonly ComboBox flow = SelectBox(new[] {"None","RTS/CTS","XON/XOFF","RTS/CTS + XON/XOFF"}, "RTS/CTS", 180);
    readonly ComboBox format = SelectBox(new[] {"ASCII","HEX"}, "ASCII", 75);
    readonly ComboBox ending = SelectBox(new[] {"None","CR","LF","CRLF"}, "None", 75);
    readonly CheckBox rts = new CheckBox {Text="PC RTS", Checked=true, AutoSize=true};
    readonly CheckBox dtr = new CheckBox {Text="PC DTR", AutoSize=true};
    readonly Button connect = new Button {Text="Kết nối", AutoSize=true};
    readonly Button refresh = new Button {Text="Tìm COM", AutoSize=true};
    readonly Button send = new Button {Text="Gửi", AutoSize=true};
    readonly Label status = new Label {Text="Chưa kết nối", AutoSize=true};
    readonly Label modem = new Label {Text="CTS: —    DSR: —", AutoSize=true};
    readonly TextBox entry = new TextBox {Width=580};
    readonly RichTextBox tx = LogBox(Color.RoyalBlue);
    readonly RichTextBox rx = LogBox(Color.DarkGreen);
    readonly RichTextBox events = LogBox(Color.Black);
    readonly Timer timer = new Timer {Interval=40};
    SerialPort serial;
    bool writing, working, shuttingDown;

    static ComboBox SelectBox(string[] values, string initial, int width)
    {
        var box = new ComboBox {DropDownStyle=ComboBoxStyle.DropDownList, Width=width};
        box.Items.AddRange(values); if (values.Contains(initial)) box.SelectedItem=initial; return box;
    }
    static RichTextBox LogBox(Color color)
    {
        return new RichTextBox {Dock=DockStyle.Fill, ReadOnly=true, BackColor=Color.White,
            ForeColor=color, Font=new Font("Consolas",10), WordWrap=true};
    }
    static Control Field(string label, Control input)
    {
        var group = new FlowLayoutPanel {FlowDirection=FlowDirection.TopDown, AutoSize=true, WrapContents=false};
        group.Controls.Add(new Label {Text=label, AutoSize=true}); group.Controls.Add(input); return group;
    }
    public UartConsole()
    {
        Text="UART Console — C# / .NET"; Size=new Size(1120,760); MinimumSize=new Size(1000,650);
        Font=new Font("Segoe UI",10); StartPosition=FormStartPosition.CenterScreen;
        var layout=new TableLayoutPanel {Dock=DockStyle.Fill, Padding=new Padding(14), RowCount=7, ColumnCount=1};
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,44));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,76));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,44));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,30));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,50));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,135));
        layout.Controls.Add(new Label {Text="UART CONSOLE  /  C#", AutoSize=true, Font=new Font("Segoe UI",20,FontStyle.Bold)},0,0);
        var settings=new FlowLayoutPanel {Dock=DockStyle.Fill, WrapContents=false};
        settings.Controls.AddRange(new[] {Field("COM",port),Field("Baudrate",baud),Field("Data bits",bits),Field("Parity",parity),Field("Stop bits",stop),Field("Handshake",flow)});
        layout.Controls.Add(settings,0,1);
        var actions=new FlowLayoutPanel {Dock=DockStyle.Fill};
        actions.Controls.AddRange(new Control[] {refresh,connect,rts,dtr,modem}); layout.Controls.Add(actions,0,2);
        layout.Controls.Add(status,0,3);
        var split=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=2,RowCount=1};
        split.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50)); split.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
        var left=new GroupBox {Text="TX — driver nhận để gửi",Dock=DockStyle.Fill}; left.Controls.Add(tx);
        var right=new GroupBox {Text="RX — dữ liệu nhận từ COM",Dock=DockStyle.Fill}; right.Controls.Add(rx);
        split.Controls.Add(left,0,0);split.Controls.Add(right,1,0); layout.Controls.Add(split,0,4);
        var sender=new FlowLayoutPanel {Dock=DockStyle.Fill,Padding=new Padding(0,8,0,0)};
        var clear=new Button {Text="Xóa",AutoSize=true}; var save=new Button {Text="Lưu log",AutoSize=true};
        sender.Controls.AddRange(new Control[] {entry,format,ending,send,clear,save}); layout.Controls.Add(sender,0,5);
        layout.Controls.Add(events,0,6); Controls.Add(layout);
        refresh.Click+=(s,e)=>Discover(); connect.Click+=async(s,e)=>await Toggle();
        send.Click+=async(s,e)=>await Transmit();
        entry.KeyDown+=async(s,e)=> {if(e.KeyCode==Keys.Enter){e.SuppressKeyPress=true;await Transmit();}};
        clear.Click+=(s,e)=>{tx.Clear();rx.Clear();}; save.Click+=(s,e)=>SaveLog();
        flow.SelectedIndexChanged+=(s,e)=>ControlsState();
        rts.CheckedChanged+=(s,e)=>SetLine(true);dtr.CheckedChanged+=(s,e)=>SetLine(false);
        timer.Tick+=(s,e)=>Receive(); timer.Start();
        FormClosing+=OnClosing; Discover(); ControlsState();
        Log(events,"C# .NET " + Environment.Version + " | " + (Environment.Is64BitProcess ? "64-bit" : "32-bit"));
    }
    static void Log(RichTextBox target,string message)
    {
        if(target.TextLength>250000) target.Clear();
        target.AppendText(DateTime.Now.ToString("HH:mm:ss.fff")+"  "+message+Environment.NewLine);
        target.SelectionStart=target.TextLength;target.ScrollToCaret();
    }
    static string ErrorText(Exception error)
    {
        return error.GetType().Name+": "+error.Message+" (HRESULT 0x"+error.HResult.ToString("X8")+")";
    }
    bool HardwareFlow {get{return flow.Text.StartsWith("RTS/CTS");}}
    void ControlsState()
    {
        bool opened=serial!=null && serial.IsOpen;
        foreach(var field in new[] {port,baud,bits,parity,stop,flow}) field.Enabled=!opened&&!working;
        refresh.Enabled=!opened&&!working; connect.Enabled=!working&&!writing;
        connect.Text=opened?"Ngắt kết nối":"Kết nối";
        send.Enabled=opened&&!working&&!writing;
        rts.Enabled=!HardwareFlow&&!working&&!writing; dtr.Enabled=!working&&!writing;
    }
    void Discover()
    {
        try {string previous=port.Text; var names=SerialPort.GetPortNames().OrderBy(x=>x.Length).ThenBy(x=>x).ToArray();
            port.Items.Clear();port.Items.AddRange(names);
            if(names.Length>0) port.SelectedItem=names.Contains(previous)?previous:names.Contains("COM9")?"COM9":names[0];
            Log(events,"COM: "+string.Join(", ",names));}
        catch(Exception error){Log(events,ErrorText(error));}
    }
    async Task Toggle()
    {
        if(working||writing)return;
        if(serial!=null){Disconnect();return;}
        if(port.SelectedItem==null){MessageBox.Show("Chọn cổng COM.");return;}
        Handshake handshake=flow.Text=="None"?Handshake.None:flow.Text=="RTS/CTS"?Handshake.RequestToSend:
            flow.Text=="XON/XOFF"?Handshake.XOnXOff:Handshake.RequestToSendXOnXOff;
        var candidate=new SerialPort(port.Text,int.Parse(baud.Text),(Parity)Enum.Parse(typeof(Parity),parity.Text),
            int.Parse(bits.Text),stop.Text=="1"?StopBits.One:StopBits.Two);
        candidate.Handshake=handshake; candidate.DtrEnable=dtr.Checked;
        if(!HardwareFlow)candidate.RtsEnable=rts.Checked;
        candidate.ReadTimeout=100; candidate.WriteTimeout=1000; candidate.ParityReplace=0;
        string description=port.Text+" | "+baud.Text+" | "+bits.Text+parity.Text[0]+stop.Text+" | "+flow.Text;
        working=true;ControlsState(); status.Text="Đang mở cổng…";Log(events,"OPEN REQUEST: "+description);
        try {await Task.Run(()=>candidate.Open());serial=candidate;status.Text=description;Log(events,"OPEN OK: "+description);}
        catch(Exception error){candidate.Dispose();status.Text="Không mở/cấu hình được COM";Log(events,ErrorText(error));}
        finally {working=false;ControlsState();if(shuttingDown)Close();}
    }
    void Disconnect()
    {
        var old=serial;serial=null;
        if(old!=null){try{old.Dispose();}catch(Exception error){Log(events,ErrorText(error));}}
        status.Text="Đã đóng cổng";modem.Text="CTS: —    DSR: —";Log(events,"CLOSED");ControlsState();
    }
    void SetLine(bool isRts)
    {
        if(serial==null||working||writing)return;
        try{if(isRts){if(!HardwareFlow)serial.RtsEnable=rts.Checked;}else serial.DtrEnable=dtr.Checked;}
        catch(Exception error){Log(events,ErrorText(error));Disconnect();}
    }
    public static byte[] Encode(string text,bool hex,string suffix,int width)
    {
        byte[] data;
        if(hex){string compact=new string(text.Where(c=>!char.IsWhiteSpace(c)).ToArray());
            if(compact.Length%2!=0)throw new FormatException("HEX cần đủ hai chữ số cho mỗi byte.");
            data=Enumerable.Range(0,compact.Length/2).Select(i=>Convert.ToByte(compact.Substring(i*2,2),16)).ToArray();}
        else {if(text.Any(c=>c>127))throw new FormatException("ASCII chỉ nhận ký tự 0–127; dùng HEX để gửi byte khác.");data=Encoding.ASCII.GetBytes(text);}
        string tail=suffix=="CR"?"\r":suffix=="LF"?"\n":suffix=="CRLF"?"\r\n":"";
        data=data.Concat(Encoding.ASCII.GetBytes(tail)).ToArray();
        if(data.Length==0||data.Length>4096)throw new FormatException("Gửi từ 1 đến 4096 byte.");
        if(data.Any(b=>b>=(1<<width)))throw new FormatException("Byte vượt phạm vi data bits đã chọn.");return data;
    }
    static string Render(byte[] data)
    {
        return data.Length+" byte | "+string.Concat(data.Select(b=>b>=32&&b<127?((char)b).ToString():"\\x"+b.ToString("X2")))+
            Environment.NewLine+"HEX: "+BitConverter.ToString(data).Replace('-',' ');
    }
    async Task Transmit()
    {
        if(serial==null||writing||working)return;
        byte[] data;try{data=Encode(entry.Text,format.Text=="HEX",ending.Text,int.Parse(bits.Text));}
        catch(Exception error){MessageBox.Show(error.Message,"Dữ liệu gửi");return;}
        var current=serial;writing=true;ControlsState();
        try{await Task.Run(()=>current.Write(data,0,data.Length));Log(tx,Render(data));}
        catch(Exception error){Log(events,"TX: "+ErrorText(error)+" Có thể đã gửi một phần; không tự gửi lại.");}
        finally{writing=false;ControlsState();if(shuttingDown)Close();}
    }
    void Receive()
    {
        if(serial==null||working||shuttingDown)return;
        try {int count=Math.Min(serial.BytesToRead,8192);
            if(count>0){var buffer=new byte[count];int got=serial.Read(buffer,0,count);Log(rx,Render(buffer.Take(got).ToArray()));}
            modem.Text="CTS: "+(serial.CtsHolding?"asserted":"off")+"    DSR: "+(serial.DsrHolding?"asserted":"off");}
        catch(TimeoutException){}
        catch(Exception error){Log(events,ErrorText(error));if(!writing)Disconnect();}
    }
    void SaveLog()
    {
        using(var dialog=new SaveFileDialog {Filter="Text|*.txt",FileName="uart-log.txt"})
            if(dialog.ShowDialog()==DialogResult.OK)
                try{File.WriteAllText(dialog.FileName,"EVENTS\r\n"+events.Text+"\r\nTX\r\n"+tx.Text+"\r\nRX\r\n"+rx.Text,Encoding.UTF8);}
                catch(Exception error){MessageBox.Show(error.Message);}
    }
    void OnClosing(object sender,FormClosingEventArgs e)
    {
        if(writing||working){shuttingDown=true;e.Cancel=true;return;}
        timer.Stop();Disconnect();timer.Dispose();
    }
    [STAThread]
    public static void Main(string[] args)
    {
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        if(args.Length==2 && args[0]=="--check-port")
        {
            var report=new StringBuilder();bool passed=true;
            foreach(int rate in new[]{4800,115200}) foreach(Parity p in new[]{Parity.None,Parity.Odd,Parity.Even})
                foreach(Handshake h in new[]{Handshake.None,Handshake.RequestToSend})
                {
                    using(var probe=new SerialPort(args[1],rate,p,8,StopBits.One))
                    {
                        probe.Handshake=h;probe.DtrEnable=false;
                        if(h==Handshake.None)probe.RtsEnable=true;
                        try{probe.Open();report.AppendLine("PASS "+rate+" 8"+p+"1 "+h);}
                        catch(Exception error){passed=false;report.AppendLine("FAIL "+rate+" 8"+p+"1 "+h+": "+ErrorText(error));}
                    }
                }
            File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"port-check.txt"),report.ToString());
            Environment.ExitCode=passed?0:1;return;
        }
        if(args.Contains("--self-test"))
        {
            if(!Encode("00 FF 41",true,"None",8).SequenceEqual(new byte[]{0,255,65}))throw new Exception("HEX test");
            if(!Encode("AC",false,"CRLF",8).SequenceEqual(new byte[]{65,67,13,10}))throw new Exception("ASCII test");
            bool rejected=false;try{Encode("FF",true,"None",7);}catch(FormatException){rejected=true;}
            if(!rejected)throw new Exception("Width check");
            using(var form=new UartConsole()){form.CreateControl();if(form.send.Enabled)throw new Exception("Disconnected send");}
            File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"self-test.txt"),"PASS: input encoding, data width guard, UI initialization; no COM opened.");
            return;
        }
        Application.Run(new UartConsole());
    }
}
