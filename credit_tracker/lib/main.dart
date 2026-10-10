import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const CreditApp()); }
class CreditApp extends StatelessWidget {
  const CreditApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title:'GIT Credit Tracker', debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff1263d6)),scaffoldBackgroundColor:const Color(0xfff4f7fb)),
    home:const CreditHome());
}
class Loan {
  Loan({required this.name,required this.balance,this.day=0,this.kind='Vay',this.note=''});
  String name,kind,note; int balance,day;
  factory Loan.fromJson(dynamic j)=>Loan(name:j['name']??'',balance:(j['balance'] as num?)?.toInt()??0,day:(j['day'] as num?)?.toInt()??0,kind:j['kind']??'Vay',note:j['note']??'');
  Map<String,dynamic> toJson()=>{'name':name,'balance':balance,'day':day,'kind':kind,'note':note};
}
class Score {
  Score(this.date,this.value);
  String date; int value;
  factory Score.fromJson(dynamic j)=>Score(j['date']??'',(j['value'] as num?)?.toInt()??0);
  Map<String,dynamic> toJson()=>{'date':date,'value':value};
}
String money(int n) { final digits=n.abs().toString(); final b=StringBuffer(); for(var i=0;i<digits.length;i++){if(i>0&&(digits.length-i)%3==0)b.write('.');b.write(digits[i]);}return '${n<0?'-':''}${b.toString()} đ';}
class CreditHome extends StatefulWidget {const CreditHome({super.key});@override State<CreditHome> createState()=>_CreditHomeState();}
class _CreditHomeState extends State<CreditHome>{
  int tab=0; bool loading=true; List<Loan> loans=[];List<Score> scores=[]; List<Map<String,dynamic>> history=[];
  final titles=['Tổng quan','Khoản vay','Lịch trả nợ','Điểm CIC','Cài đặt'];
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    try{final p=await SharedPreferences.getInstance();loans=(jsonDecode(p.getString('git_loans_v103')??'[]') as List).map(Loan.fromJson).toList();scores=(jsonDecode(p.getString('git_scores_v103')??'[]') as List).map(Score.fromJson).toList();history=(jsonDecode(p.getString('git_history_v103')??'[]') as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();}catch(_){loans=[];scores=[];history=[];}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setString('git_loans_v103',jsonEncode(loans.map((e)=>e.toJson()).toList()));await p.setString('git_scores_v103',jsonEncode(scores.map((e)=>e.toJson()).toList()));await p.setString('git_history_v103',jsonEncode(history));if(mounted)setState((){});}
  int get total=>loans.fold(0,(int s,l)=>s+l.balance);
  Widget tile(String title,String subtitle,{IconData icon=Icons.account_balance_wallet_outlined,VoidCallback? action})=>Card(margin:const EdgeInsets.symmetric(horizontal:14,vertical:5),child:ListTile(leading:Icon(icon,color:const Color(0xff1263d6)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(subtitle),onTap:action,trailing:action==null?null:const Icon(Icons.chevron_right)));
  Future<void> editLoan([Loan? old])async{
    final name=TextEditingController(text:old?.name??'');final balance=TextEditingController(text:old?.balance.toString()??'');final day=TextEditingController(text:old?.day==0?'':old!.day.toString());final note=TextEditingController(text:old?.note??'');
    String kind=old?.kind??'Vay';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:Text(old==null?'Thêm khoản vay':'Sửa khoản vay'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Tổ chức / tên khoản vay')),
      TextField(controller:balance,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Dư nợ (VND)')),
      TextField(controller:day,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Ngày đến hạn mỗi tháng (1–31)')),
      DropdownButton<String>(value:kind,isExpanded:true,items:['Vay','Thẻ tín dụng'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>update(()=>kind=v!)),
      TextField(controller:note,decoration:const InputDecoration(labelText:'Ghi chú')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lưu'))])));
    if(ok==true){final n=int.tryParse(balance.text.trim());final d=int.tryParse(day.text.trim())??0;if(name.text.trim().isEmpty||n==null||n<0||d<0||d>31){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Kiểm tra lại tên, dư nợ và ngày đến hạn')));return;}if(old==null){loans.add(Loan(name:name.text.trim(),balance:n,day:d,kind:kind,note:note.text.trim()));}else{old.name=name.text.trim();old.balance=n;old.day=d;old.kind=kind;old.note=note.text.trim();}await save();}
  }
  Future<void> pay(Loan loan)async{
    final amount=TextEditingController();String type='Trả gốc';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(title:Text(loan.name),content:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('Dư nợ: ${money(loan.balance)}'),
      DropdownButton<String>(value:type,isExpanded:true,items:['Trả gốc','Trả lãi / phí','Tăng dư nợ'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>update(()=>type=v!)),
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Số tiền VND')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Ghi nhận'))])));
    if(ok!=true)return;final n=int.tryParse(amount.text.trim());if(n==null||n<=0||(type=='Trả gốc'&&n>loan.balance)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Số tiền không hợp lệ')));return;}
    if(type=='Trả gốc')loan.balance-=n;if(type=='Tăng dư nợ')loan.balance+=n;
    history.insert(0,{'name':loan.name,'type':type,'amount':n,'time':DateTime.now().toIso8601String()});await save();
  }
  Widget overview()=>ListView(children:[
    Card(margin:const EdgeInsets.all(14),color:const Color(0xff1263d6),child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('TỔNG DƯ NỢ',style:TextStyle(color:Colors.white70)),const SizedBox(height:8),Text(money(total),style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),Text('${loans.length} khoản • ${loans.map((e)=>e.name).toSet().length} tổ chức',style:const TextStyle(color:Colors.white70))]))),
    tile('Điểm CIC mới nhất',scores.isEmpty?'Chưa nhập điểm CIC':'${scores.last.value} điểm – ${scores.last.date}',icon:Icons.insights,action:()=>setState(()=>tab=3)),
    tile('Quản lý khoản vay','Thêm khoản vay, giảm gốc, ghi trả lãi',action:()=>setState(()=>tab=1)),
    tile('Lịch thanh toán','Xem ngày đến hạn đã nhập',icon:Icons.event,action:()=>setState(()=>tab=2)),
    const Padding(padding:EdgeInsets.all(16),child:Text('Dữ liệu chỉ lưu trên thiết bị. Ứng dụng không kết nối trực tiếp CIC hoặc ngân hàng.',style:TextStyle(color:Colors.black54))),
    for(final e in history.take(6))tile(e['name'] as String,'${e['type']} • ${money((e['amount'] as num).toInt())} • ${(e['time'] as String).substring(0,10)}',icon:Icons.receipt_long),
  ]);
  Widget accounts()=>ListView(children:[
    Padding(padding:const EdgeInsets.all(14),child:FilledButton.icon(onPressed:()=>editLoan(),icon:const Icon(Icons.add),label:const Text('Thêm khoản vay'))),
    if(loans.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Text('Chưa có khoản vay. Nhấn Thêm khoản vay để nhập dữ liệu riêng của bạn.',textAlign:TextAlign.center)),
    for(final loan in loans)Card(margin:const EdgeInsets.symmetric(horizontal:14,vertical:5),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(loan.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),Text('${loan.kind} • ${money(loan.balance)}'),if(loan.day>0)Text('Đến hạn ngày ${loan.day} hàng tháng'),if(loan.note.isNotEmpty)Text(loan.note),Wrap(spacing:8,children:[TextButton.icon(onPressed:()=>pay(loan),icon:const Icon(Icons.payments),label:const Text('Thanh toán')),TextButton.icon(onPressed:()=>editLoan(loan),icon:const Icon(Icons.edit),label:const Text('Sửa')),TextButton.icon(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Xóa khoản vay?'),content:Text(loan.name),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Xóa'))]));if(ok==true){loans.remove(loan);await save();}},icon:const Icon(Icons.delete_outline),label:const Text('Xóa'))])]))),
  ]);
  Widget schedule()=>ListView(children:[const Padding(padding:EdgeInsets.all(16),child:Text('Các ngày đến hạn bạn đã nhập. Chưa có thông báo khi ứng dụng đóng.',style:TextStyle(color:Colors.black54))),for(final loan in [...loans.where((a)=>a.day>0)]..sort((a,b)=>a.day.compareTo(b.day)))tile('Ngày ${loan.day} • ${loan.name}',money(loan.balance),icon:Icons.calendar_month,action:()=>pay(loan))]);
  Future<void> addScore()async{final date=TextEditingController(text:DateTime.now().toIso8601String().substring(0,10));final value=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Thêm điểm CIC'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:date,decoration:const InputDecoration(labelText:'Ngày YYYY-MM-DD')),TextField(controller:value,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Điểm'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Lưu'))]));if(ok==true){final n=int.tryParse(value.text.trim());if(n==null||n<0||n>1000||DateTime.tryParse(date.text.trim())==null)return;scores.add(Score(date.text.trim(),n));scores.sort((a,b)=>a.date.compareTo(b.date));await save();}}
  Widget cic()=>ListView(children:[Padding(padding:const EdgeInsets.all(14),child:FilledButton.icon(onPressed:addScore,icon:const Icon(Icons.add_chart),label:const Text('Thêm kết quả CIC'))),if(scores.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Chưa có dữ liệu CIC. Nhập từ báo cáo chính thức của bạn.')),for(final s in scores.reversed)tile('${s.value} điểm',s.date,icon:Icons.assessment)]);
  Widget settings()=>ListView(children:[tile('Chế độ offline','Không truyền thông tin tài chính lên máy chủ',icon:Icons.shield_outlined),tile('Dữ liệu','Lưu bằng SharedPreferences trên điện thoại. Hãy bảo vệ thiết bị bằng mã PIN.',icon:Icons.lock_outline),tile('Phiên bản','GIT Credit Tracker 1.0.3',icon:Icons.info_outline)]);
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('GIT • ${titles[tab]}'),backgroundColor:Colors.white),body:loading?const Center(child:CircularProgressIndicator()):[overview(),accounts(),schedule(),cic(),settings()][tab],bottomNavigationBar:NavigationBar(height:76,selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Tổng quan'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'Khoản vay'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'Lịch trả'),NavigationDestination(icon:Icon(Icons.auto_graph),label:'CIC'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Cài đặt')]));
}
