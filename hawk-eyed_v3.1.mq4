#property version       "1.00"
#property strict

#property description   "This Expert Advisor opens orders when the Stochastic oscillator passes one of the thresholds"
#property description   " "
#property description   "DISCLAIMER: This code comes with no guarantee, you can use it at your own risk"
#property description   "We recommend to test it first on a Demo Account"

/*
ENTRY BUY: when the fast MA crosses the slow from the bottom, both MA are going up
ENTRY SELL: when the fast MA crosses the slow from the top, both MA are going down
EXIT: When Stop Loss or Take Profit are reached or, reaching the upper threshold for buy orders and reaching the lower threshold for sell orders
Only 1 order at a time
*/


extern double LotSize=1;             //Position size

extern double StopLoss=150;             //Stop loss in pips
extern double TakeProfit=115000;           //Take profit in pips

//extern int Slippage=2;                 //Slippage in pips

extern bool TradeEnabled=true;         //Enable trade

extern int fast_k = 13;
extern int fast_d = 3;
extern int fast_smoothing = 1;

extern int slow_k = 34;
extern int slow_d = 5;
extern int slow_smoothing = 1;

extern int UpperThreshold=89;          //Upper Threshold, default 80
extern int LowerThreshold=13;          //Lower Threshold, default 20
//extern int UpperLowThreshold=80;
//extern int LowerUpThreshold=20;


extern int time_buffer = 2;

//Functional variables
double ePoint;                         //Point normalized

bool CanOrder;                         //Check for risk management
bool CanOpenBuy;                       //Flag if there are buy orders open
bool CanOpenSell;                      //Flag if there are sell orders open

int OrderOpRetry=10;                   //Number of attempts to perform a trade operation
int SleepSecs=3;                       //Seconds to sleep if can't order
int MinBars=14;                        //Minimum bars in the graph to enable trading

//Functional variables to determine prices
double MinSL;
double MaxSL;
double TP;
double SL;
double Spread;
int Slip; 


//Variable initialization function
void Initialize(){          
   RefreshRates();
   ePoint=Point;
   //Slip=Slippage;
   //if (MathMod(Digits,2)==1){
   //   ePoint*=10;
   //   Slip*=10;
   //}
   if (Digits <= 3){
      ePoint=0.01;
   }
   // If there are 4 or more digits, then return 0.0001, which is the pip value.
   else if (Digits >= 4){
      ePoint=0.0001;
   }
   TP=TakeProfit*ePoint;
   SL=StopLoss*ePoint;
   CanOrder=TradeEnabled;
   CanOpenBuy=true;
   CanOpenSell=true;
   HideTestIndicators(TRUE);
}


//Check if orders can be submitted
void CheckCanOrder(){            
   if( Bars<MinBars ){
      Print("INFO - Not enough Bars to trade");
      CanOrder=false;
   }
   OrdersOpen();
   return;
}


//Check if there are open orders and what type
void OrdersOpen(){
   for( int i = 0 ; i < OrdersTotal() ; i++ ) {
      if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
      } 
      if( OrderSymbol()==Symbol() && OrderType() == OP_BUY) CanOpenBuy=false;
      if( OrderSymbol()==Symbol() && OrderType() == OP_SELL) CanOpenSell=false;
   }
   return;
}


//Close all the orders of a specific type and current symbol
void CloseAll(int Command){
   double ClosePrice=0;
   for( int i = 0 ; i < OrdersTotal() ; i++ ) {
      if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
      }
      if( OrderSymbol()==Symbol() && OrderType()==Command) {
         if(Command==OP_BUY) ClosePrice=Bid;
         if(Command==OP_SELL) ClosePrice=Ask;
         double Lots=OrderLots();
         int Ticket=OrderTicket();
         for(int j=1; j<OrderOpRetry; j++){
            bool res=OrderClose(Ticket,Lots,ClosePrice,Slip,Red);
            if(res){
               Print("TRADE - CLOSE - Order ",Ticket," closed at price ",ClosePrice);
               break;
            }
            else Print("ERROR - CLOSE - error closing order ",Ticket," return error: ",GetLastError());
         }
      }
   }
   return;
}

double OpenPrice=0;

//Open new order of a given type
void OpenNew(int Command){
   RefreshRates();
   OpenPrice=0;
   double SLPrice = 0;
   double TPPrice = 0;
   if(Command==OP_BUY){
      OpenPrice=Ask;
      SLPrice=OpenPrice-SL;
      TPPrice=OpenPrice+TP;
   }
   if(Command==OP_SELL){
      OpenPrice=Bid;
      SLPrice=OpenPrice+SL;
      TPPrice=OpenPrice-TP;
   }
   for(int i=1; i<OrderOpRetry; i++){
      int res=OrderSend(Symbol(),Command,LotSize,OpenPrice,Slip,NormalizeDouble(SLPrice,Digits),NormalizeDouble(TPPrice,Digits),"",0,0,Green);
      if(res){
         Print("TRADE - NEW - Order ",res," submitted: Command ",Command," Volume ",LotSize," Open ",OpenPrice," Slippage ",Slip," Stop ",SLPrice," Take ",TPPrice);
         break;
      }
      else Print("ERROR - NEW - error sending order, return error: ",GetLastError());
   }
   return;
}

void CloseHalf(int Command){
   double ClosePrice=0;
   for( int i = 0 ; i < OrdersTotal() ; i++ ) {
      if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
      }
      if( OrderSymbol()==Symbol() && OrderType()==Command) {
         if(Command==OP_BUY) ClosePrice=Bid;
         if(Command==OP_SELL) ClosePrice=Ask;
         double Lots=OrderLots();
         int Ticket=OrderTicket();
         for(int j=1; j<OrderOpRetry; j++){
            bool res=OrderClose(Ticket,Lots/3,ClosePrice,Slip,Red);
            if(res){
               Print("TRADE - CLOSE - Order ",Ticket," closed at price ",ClosePrice);
               break;
            }
            else Print("ERROR - CLOSE - error closing order ",Ticket," return error: ",GetLastError());
         }
      }
   }
   return;
}

//void TrailingSL(int TrailingPoint){
//   for (int i=OrdersTotal() - 1;i>=0;i--) {
//      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
//         if ((OrderType() == OP_BUY) && 
//         (NormalizeDouble(Bid - OrderStopLoss(),Digits) > NormalizeDouble(TrailingPoint * Point,Digits))) {
//            if (
//            OrderModify(
//            OrderTicket(),
//            OrderOpenPrice(),
//            NormalizeDouble(Bid - TrailingPoint * Point,Digits),
//            OrderTakeProfit(),
//            OrderExpiration(),
//            clrNONE) == false) {
//               }
//          else if ((OrderType() == OP_SELL) &&
//          (NormalizeDouble(OrderStopLoss() - Ask,Digits) > NormalizeDouble(TrailingPoint * Point,Digits))) {
//            if (
//            OrderModify(
//            OrderTicket(),
//            OrderOpenPrice(),
//            NormalizeDouble(Ask + TrailingPoint * Point,Digits),
//            OrderTakeProfit(),
//            OrderExpiration(),
//            clrNONE) == false) {
//               }
//            }
//         }
//      }
//   }
//}

void TrailingSL(){
   double atr=iATR(Symbol(),0,22,0);
   double chandelier_long=iHigh(Symbol(),0,0)-3*atr;
   double chandelier_short=iLow(Symbol(),0,0)+3*atr;
   //double chandelier_long=High[iHighest(Symbol(), 0, MODE_HIGH, 1, 1)]-3*atr;
   //double chandelier_short=High[iHighest(Symbol(), 0, MODE_HIGH, 1, 1)]+3*atr;

   for (int i=OrdersTotal() - 1;i>=0;i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if ((OrderType() == OP_BUY) && 
         (NormalizeDouble(Bid - OrderStopLoss(),Digits) > NormalizeDouble(Bid - chandelier_long,Digits))) {
            //if (
            OrderModify(
            OrderTicket(),
            OrderOpenPrice(),
            chandelier_long,
            OrderTakeProfit(),
            OrderExpiration(),
            clrNONE);
            }
          else if ((OrderType() == OP_SELL) &&
          (NormalizeDouble(OrderStopLoss() - Ask,Digits) > NormalizeDouble(chandelier_short - Ask,Digits))) {
           // if (
            OrderModify(
            OrderTicket(),
            OrderOpenPrice(),
            chandelier_short,
            OrderTakeProfit(),
            OrderExpiration(),
            clrNONE) ;
               
            
         }
      }
   }
}

void TrailingTP(int TrailingPoint){
   for (int i=OrdersTotal() - 1;i>=0;i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if ((OrderType() == OP_BUY) && 
         (NormalizeDouble(OrderTakeProfit() - Bid,Digits) < NormalizeDouble(TrailingPoint * Point,Digits))) {
            if (
            OrderModify(
            OrderTicket(),
            OrderOpenPrice(),
            OrderStopLoss(),
            NormalizeDouble(Bid + TrailingPoint * Point,Digits),
            OrderExpiration(),
            clrNONE) == false) {
               }
          else if ((OrderType() == OP_SELL) &&
          (NormalizeDouble(Ask - OrderTakeProfit(),Digits) < NormalizeDouble(TrailingPoint * Point,Digits))) {
            if (
            OrderModify(
            OrderTicket(),
            OrderOpenPrice(),
            OrderStopLoss(),
            NormalizeDouble(Ask - TrailingPoint * Point,Digits),
            OrderExpiration(),
            clrNONE) == false) {
               }
            }
         }
      }
   }
}

//Technical analysis of the indicators
bool CrossToOpenBuy=false;
bool CrossToOpenSell=false;
bool CrossToCloseBuy=false;
bool CrossToCloseSell=false;
bool CrossToCloseHalfBuy=false;
bool CrossToCloseHalfSell=false;


void CheckStochCross(){
   CrossToOpenBuy=false;
   CrossToOpenSell=false;
   CrossToCloseBuy=false;
   CrossToCloseSell=false;
   CrossToCloseHalfBuy=false;
   CrossToCloseHalfSell=false;
   double curr_fast_k=iStochastic(Symbol(),0,fast_k,fast_d,fast_smoothing,MODE_SMA,0,MODE_BASE,1);
   double curr_slow_k=iStochastic(Symbol(),0,slow_k,slow_d,slow_smoothing,MODE_SMA,0,MODE_BASE,1);
   double pre1_fast_k=iStochastic(Symbol(),0,fast_k,fast_d,fast_smoothing,MODE_SMA,0,MODE_BASE,2);
   double pre1_slow_k=iStochastic(Symbol(),0,slow_k,slow_d,slow_smoothing,MODE_SMA,0,MODE_BASE,2);
   double pre2_fast_k=iStochastic(Symbol(),0,fast_k,fast_d,fast_smoothing,MODE_SMA,0,MODE_BASE,3);
   double curr_adx=iADX(NULL,0,13,PRICE_HIGH,MODE_MAIN,1);
   double pre_adx=iADX(NULL,0,13,PRICE_HIGH,MODE_MAIN,2);
   //double curr_ma=iMA(Symbol(),0,34,0,MODE_SMA,0,1);
   //double pre_ma=iMA(Symbol(),0,34,0,MODE_SMA,0,2);
   //double short_ma=iMA(Symbol(),0,1,0,MODE_SMA,0,0);
   //double middle_ma=iMA(Symbol(),0,12,0,MODE_SMA,0,0);
   //double long_ma=iMA(Symbol(),0,48,0,MODE_SMA,0,0);
   
   double tmp1=iMA(Symbol(),0,26,0,MODE_SMA,0,1);
   double tmp2=iMA(Symbol(),0,26,0,MODE_LWMA,0,1);
   double linreg_curr=3.0*tmp2-2.0*tmp1;
   
   tmp1=iMA(Symbol(),0,26,0,MODE_SMA,0,2);
   tmp2=iMA(Symbol(),0,26,0,MODE_LWMA,0,2);
   double linreg_pre_1=3.0*tmp2-2.0*tmp1;
   
   tmp1=iMA(Symbol(),0,26,0,MODE_SMA,0,3);
   tmp2=iMA(Symbol(),0,26,0,MODE_LWMA,0,3);
   double linreg_pre_2=3.0*tmp2-2.0*tmp1;

   double adx_adx_line=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MAIN,0);
   double adx_plus_DI_2=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_PLUSDI,2);
   double adx_minus_DI_2=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MINUSDI,2);
   double adx_plus_DI_1=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_PLUSDI,1);
   double adx_minus_DI_1=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MINUSDI,1);
   double adx_plus_DI_0=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_PLUSDI,0);
   double adx_minus_DI_0=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MINUSDI,1);
   double adx_plus_DI_3=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_PLUSDI,3);
   double adx_minus_DI_3=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MINUSDI,3);
   double adx_plus_DI_4=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_PLUSDI,4);
   double adx_minus_DI_4=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MINUSDI,4);
   double adx_plus_DI_5=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_PLUSDI,5);
   double adx_minus_DI_5=iADX(Symbol(),0,13,PRICE_CLOSE,MODE_MINUSDI,5);


   if ((linreg_curr-linreg_pre_1)/linreg_pre_1*100>0.01
   //linreg_curr-linreg_pre_1>linreg_pre_1-linreg_pre_2
   //linreg_curr>linreg_pre_1 
   //linreg_pre_1>linreg_pre_2 &&
   //curr_adx>pre_adx
   //curr_adx>30 &&
    //(adx_plus_DI_2<adx_minus_DI_2 &&
    //adx_plus_DI_1<adx_minus_DI_1 &&
    //adx_plus_DI_0>adx_minus_DI_0 
    //(adx_plus_DI_3<adx_minus_DI_3 &&
    //adx_plus_DI_2<=adx_minus_DI_2 &&
    //adx_plus_DI_1>adx_minus_DI_1) ||
    //(adx_plus_DI_4<adx_minus_DI_4 &&
    //adx_plus_DI_3<=adx_minus_DI_3 &&
    //adx_plus_DI_2>adx_minus_DI_2) ||
    //(adx_plus_DI_5<adx_minus_DI_5 &&
    //adx_plus_DI_4<=adx_minus_DI_4 &&
    //adx_plus_DI_3>adx_minus_DI_3)
   ) {

      if(//Close[0]>curr_ma && 

         (curr_slow_k>LowerThreshold && pre1_slow_k<LowerThreshold) && 

         (curr_fast_k>LowerThreshold && (pre1_fast_k<LowerThreshold||pre2_fast_k<LowerThreshold))
         ){

            CrossToOpenBuy=true;

      }

   }

   

   if ((linreg_pre_1-linreg_curr)/linreg_pre_1*100>0.01
   //linreg_pre_1-linreg_curr>linreg_pre_2-linreg_pre_1
   //linreg_curr<linreg_pre_1 
   //curr_adx>pre_adx
    //curr_adx>30 &&
    //(adx_plus_DI_2>adx_minus_DI_2 &&
    //adx_plus_DI_1>adx_minus_DI_1 &&
    //adx_plus_DI_0<adx_minus_DI_0 
    //(adx_plus_DI_3>adx_minus_DI_3 &&
    //adx_plus_DI_2>=adx_minus_DI_2 &&
    //adx_plus_DI_1<adx_minus_DI_1) ||
    //(adx_plus_DI_4>adx_minus_DI_4 &&
    //adx_plus_DI_3>=adx_minus_DI_3 &&
    //adx_plus_DI_2<adx_minus_DI_2) ||
    //(adx_plus_DI_5>adx_minus_DI_5 &&
    //adx_plus_DI_4>=adx_minus_DI_4 &&
    //adx_plus_DI_3<adx_minus_DI_3) 
   ) {

      if(//Close[0]<curr_ma && 

      (curr_slow_k<UpperThreshold && pre1_slow_k>UpperThreshold) && 

      (curr_fast_k<UpperThreshold && (pre1_fast_k>UpperThreshold||pre2_fast_k>UpperThreshold))
      ){

         CrossToOpenSell=true;

      }

   }

   

//   else{

//      if(Close[0]>curr_ma && 

//      (curr_slow_k>LowerThreshold && pre1_slow_k<LowerThreshold) && 

//      (curr_fast_k>LowerThreshold && (pre1_fast_k<LowerThreshold||pre2_fast_k<LowerThreshold))){

//         CrossToOpenBuy=true;

//      }

//      

//      if(Close[0]<curr_ma && 

//      (curr_slow_k<UpperThreshold && pre1_slow_k>UpperThreshold) && 

//      (curr_fast_k<UpperThreshold && (pre1_fast_k>UpperThreshold||pre2_fast_k>UpperThreshold))){

//         CrossToOpenSell=true;

//      }

//   }

   

   //if(curr_ma<pre_ma && 

   ////OpenPrice-Close[0]>StopLoss &&

   //((curr_slow_k<UpperThreshold && pre1_slow_k>UpperThreshold) && 

   //(curr_fast_k<UpperThreshold && (pre1_fast_k>UpperThreshold||pre2_fast_k>UpperThreshold)))){

   //   CrossToCloseHalfBuy=true;

   //}

   //if((curr_ma>pre_ma && 

   ////Close[0]-OpenPrice<StopLoss &&

   //((curr_slow_k>LowerThreshold && pre1_slow_k<LowerThreshold) && 

   //(curr_fast_k>LowerThreshold && (pre1_fast_k<LowerThreshold||pre2_fast_k<LowerThreshold))))){

   //   CrossToCloseHalfSell=true;

   //}

   

   if((linreg_pre_1-linreg_curr)/linreg_pre_1*100>0.01 &&
   //linreg_curr<linreg_pre_1 &&
    //((adx_plus_DI_2>adx_minus_DI_2 &&
    //adx_plus_DI_1>=adx_minus_DI_1 &&
    //adx_plus_DI_0<adx_minus_DI_0) ||
    //(adx_plus_DI_3>adx_minus_DI_3 &&
    //adx_plus_DI_2>=adx_minus_DI_2 &&
    //adx_plus_DI_1<adx_minus_DI_1) ||
    //(adx_plus_DI_4>adx_minus_DI_4 &&
    //adx_plus_DI_3>=adx_minus_DI_3 &&
    //adx_plus_DI_2<adx_minus_DI_2) ||
    //(adx_plus_DI_5>adx_minus_DI_5 &&
    //adx_plus_DI_4>=adx_minus_DI_4 &&
    //adx_plus_DI_3<adx_minus_DI_3)) &&
   //curr_ma-pre_ma<2*Point &&

   //((OpenPrice-Close[0]>SL && curr_slow_k<LowerThreshold && pre1_slow_k>LowerThreshold)||
//
   (curr_slow_k<UpperThreshold && pre1_slow_k>UpperThreshold)
//
   //(curr_fast_k<UpperThreshold && (pre1_fast_k>UpperThreshold||pre2_fast_k>UpperThreshold))
//
   ){

      CrossToCloseBuy=true;

   }

   if((linreg_curr-linreg_pre_1)/linreg_pre_1*100>0.01 &&
   //linreg_curr>linreg_pre_1 &&
    //((adx_plus_DI_2<adx_minus_DI_2 &&
    //adx_plus_DI_1<=adx_minus_DI_1 &&
    //adx_plus_DI_0>adx_minus_DI_0) ||
    //(adx_plus_DI_3<adx_minus_DI_3 &&
    //adx_plus_DI_2<=adx_minus_DI_2 &&
    //adx_plus_DI_1>adx_minus_DI_1) ||
    //(adx_plus_DI_4<adx_minus_DI_4 &&
    //adx_plus_DI_3<=adx_minus_DI_3 &&
    //adx_plus_DI_2>adx_minus_DI_2) ||
    //(adx_plus_DI_5<adx_minus_DI_5 &&
    //adx_plus_DI_4<=adx_minus_DI_4 &&
    //adx_plus_DI_3>adx_minus_DI_3)) &&
   //curr_ma-pre_ma>2*Point &&

   //((Close[0]-OpenPrice>SL && curr_slow_k>UpperThreshold && pre1_slow_k<UpperThreshold)||
//
   ((curr_slow_k>LowerThreshold && pre1_slow_k<LowerThreshold)
//
   //(curr_fast_k>LowerThreshold && (pre1_fast_k<LowerThreshold||pre2_fast_k<LowerThreshold))
//
   )){

      CrossToCloseSell=true;

   }

}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
datetime LastActionTime = 0;

void OnTick()
  {
//---
   //Calling initialization, checks and technical analysis
   Initialize();
   CheckCanOrder();
   CheckStochCross();
   if (LastActionTime != Time[0]) {
      //TrailingSL((int)StopLoss * 8);
      //TrailingTP((int)TakeProfit * 8);
      //TrailingSL();
      if(CrossToOpenBuy){
      if(CanOpenBuy && CanOrder) OpenNew(OP_BUY);
      }
      if(CrossToOpenSell){
         if(CanOpenSell && CanOrder) OpenNew(OP_SELL);
      }
      LastActionTime = Time[0];
   }
   //Check of Entry/Exit signal with operations to perform
   if(CrossToCloseHalfBuy) CloseHalf(OP_BUY);
   if(CrossToCloseHalfSell) CloseHalf(OP_SELL);
   if(CrossToCloseBuy) CloseAll(OP_BUY);
   if(CrossToCloseSell) CloseAll(OP_SELL);
   
  }
//+------------------------------------------------------------------+
