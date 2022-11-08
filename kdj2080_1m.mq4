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

extern double StopLoss=10;             //Stop loss in pips
extern double TakeProfit=30;           //Take profit in pips

extern int Slippage=2;                 //Slippage in pips

extern bool TradeEnabled=true;         //Enable trade

extern int StochK=9;                   //Stochastic K Period, default 5
extern int StochD=3;                   //Stochastic D Period, default 3
extern int StochSlowing=3;              //Stochastic Slowing, default 3

extern int UpperThreshold=80;          //Upper Threshold, default 80
extern int LowerThreshold=20;          //Lower Threshold, default 20
extern int UpperLowThreshold=70;
extern int LowerUpThreshold=30;


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
   Slip=Slippage;
   if (MathMod(Digits,2)==1){
      ePoint*=10;
      Slip*=10;
   }
   TP=TakeProfit*ePoint;
   SL=StopLoss*ePoint;
   CanOrder=TradeEnabled;
   CanOpenBuy=true;
   CanOpenSell=true;
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


//Open new order of a given type
void OpenNew(int Command){
   RefreshRates();
   double OpenPrice=0;
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


//Technical analysis of the indicators
bool CrossToOpenBuy=false;
bool CrossToOpenSell=false;
bool CrossToCloseBuy=false;
bool CrossToCloseSell=false;


void CheckStochCross(){
   CrossToOpenBuy=false;
   CrossToOpenSell=false;
   CrossToCloseBuy=false;
   CrossToCloseSell=false;
   double StochPrev=iStochastic(Symbol(),0,StochK,StochD,StochSlowing,MODE_SMA,STO_LOWHIGH,MODE_BASE,1);
   double StochCurr=iStochastic(Symbol(),0,StochK,StochD,StochSlowing,MODE_SMA,STO_LOWHIGH,MODE_BASE,0);
   double MACDPrev=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
   double MACDCurr=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
   
   if(StochPrev<LowerThreshold && StochCurr>LowerThreshold){
      CrossToOpenBuy=true;
   }
   if(StochPrev>UpperThreshold && StochCurr<UpperThreshold){
      CrossToOpenSell=true;
   }
   if(StochCurr>UpperLowThreshold||(StochCurr<LowerThreshold&&StochPrev>LowerThreshold)){
      CrossToCloseBuy=true;
   }
   if(StochCurr<LowerUpThreshold||(StochCurr>UpperThreshold&&StochPrev<UpperThreshold)){
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
void OnTick()
  {
//---
   //Calling initialization, checks and technical analysis
   Initialize();
   CheckCanOrder();
   CheckStochCross();
   //Check of Entry/Exit signal with operations to perform
   if(CrossToCloseBuy) CloseAll(OP_BUY);
   if(CrossToCloseSell) CloseAll(OP_SELL);
   if(CrossToOpenBuy){
      if(CanOpenBuy && CanOrder) OpenNew(OP_BUY);
   }
   if(CrossToOpenSell){
      if(CanOpenSell && CanOrder) OpenNew(OP_SELL);
   }
  }
//+------------------------------------------------------------------+
