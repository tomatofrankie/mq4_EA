 //+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
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
extern double TakeProfit=1500;           //Take profit in pips

extern int Slippage=2;                 //Slippage in pips

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
void Initialize()
  {
   RefreshRates();
   ePoint=Point;
   Slip=Slippage;
   if(MathMod(Digits,2)==1)
     {
      ePoint*=10;
      Slip*=10;
     }
   TP=TakeProfit*ePoint;
   SL=StopLoss*ePoint;
   CanOrder=TradeEnabled;
   CanOpenBuy=true;
   CanOpenSell=true;
   TesterHideIndicators(False);
  }


//Check if orders can be submitted
void CheckCanOrder()
  {
   if(Bars<MinBars)
     {
      Print("INFO - Not enough Bars to trade");
      CanOrder=false;
     }
   OrdersOpen();
   return;
  }


//Check if there are open orders and what type
void OrdersOpen()
  {
   for(int i = 0 ; i < OrdersTotal() ; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
        }
      if(OrderSymbol()==Symbol() && OrderType() == OP_BUY)
         CanOpenBuy=false;
      if(OrderSymbol()==Symbol() && OrderType() == OP_SELL)
         CanOpenSell=false;
     }
   return;
  }


//Close all the orders of a specific type and current symbol
void CloseAll(int Command)
  {
   double ClosePrice=0;
   for(int i = 0 ; i < OrdersTotal() ; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
        }
      if(OrderSymbol()==Symbol() && OrderType()==Command)
        {
         if(Command==OP_BUY)
            ClosePrice=Bid;
         if(Command==OP_SELL)
            ClosePrice=Ask;
         double Lots=OrderLots();
         int Ticket=OrderTicket();
         for(int j=1; j<OrderOpRetry; j++)
           {
            bool res=OrderClose(Ticket,Lots,ClosePrice,Slip,Red);
            if(res)
              {
               Print("TRADE - CLOSE - Order ",Ticket," closed at price ",ClosePrice);
               break;
              }
            else
               Print("ERROR - CLOSE - error closing order ",Ticket," return error: ",GetLastError());
           }
        }
     }
   return;
  }

double OpenPrice=0;
int stopValue; 
int oldTime;
double SLPrice = 0;
double TPPrice = 0;

void cal_sltp(int Command)
{
   SLPrice = 0;
   TPPrice = 0;
   if(Command==OP_BUY)
     {
      OpenPrice=Ask;
      SLPrice=OpenPrice-SL;
      TPPrice=OpenPrice+TP;
     }
   if(Command==OP_SELL)
     {
      OpenPrice=Bid;
      SLPrice=OpenPrice+SL;
      TPPrice=OpenPrice-TP;
     }
   SLPrice = NormalizeDouble(SLPrice,Digits);
   TPPrice = NormalizeDouble(TPPrice,Digits);
   
   return;
}



//Open new order of a given type
void OpenNew(int Command)
  {
   RefreshRates();
   OpenPrice=0;

   if(Command==OP_BUY)
     {
      OpenPrice=Ask;
   //   SLPrice=OpenPrice-SL;
   //   TPPrice=OpenPrice+TP;
     }
   if(Command==OP_SELL)
     {
      OpenPrice=Bid;
      //SLPrice=OpenPrice+SL;
      //TPPrice=OpenPrice-TP;
     }
   for(int i=1; i<OrderOpRetry; i++)
     {
      int res=OrderSend(Symbol(),Command,LotSize,OpenPrice,Slip,NormalizeDouble(SLPrice,Digits),NormalizeDouble(TPPrice,Digits),"",0,0,Green);
      if(res)
        {
         cal_sltp(Command);
         Print("TRADE - NEW - Order ",res," submitted: Command ",Command," Volume ",LotSize," Open ",OpenPrice," Slippage ",Slip," Stop ",SLPrice," Take ",TPPrice);
         break;
        }
      else
         Print("ERROR - NEW - error sending order, return error: ",GetLastError());
     }
   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseHalf(int Command)
  {
   double ClosePrice=0;
   for(int i = 0 ; i < OrdersTotal() ; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
        }
      if(OrderSymbol()==Symbol() && OrderType()==Command)
        {
         if(Command==OP_BUY)
            ClosePrice=Bid;
         if(Command==OP_SELL)
            ClosePrice=Ask;
         double Lots=OrderLots();
         int Ticket=OrderTicket();
         for(int j=1; j<OrderOpRetry; j++)
           {
            bool res=OrderClose(Ticket,Lots/3,ClosePrice,Slip,Red);
            if(res)
              {
               Print("TRADE - CLOSE - Order ",Ticket," closed at price ",ClosePrice);
               break;
              }
            else
               Print("ERROR - CLOSE - error closing order ",Ticket," return error: ",GetLastError());
           }
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrailingSL()
  {
   double atr=iATR(Symbol(),0,22,0);
   double chandelier_long=iHighest(Symbol(),0,MODE_HIGH,20,0)-3*atr;
   double chandelier_short=iHighest(Symbol(),0,MODE_HIGH,20,0)+3*atr;

   for(int i=OrdersTotal() - 1; i>=0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if((OrderType() == OP_BUY) &&
            (NormalizeDouble(Bid - OrderStopLoss(),Digits) > NormalizeDouble(Bid - chandelier_long,Digits)))
           {
            if(
               OrderModify(
                  OrderTicket(),
                  OrderOpenPrice(),
                  chandelier_long,
                  OrderTakeProfit(),
                  OrderExpiration(),
                  clrNONE) == false)
              {
              }
            else
               if((OrderType() == OP_SELL) &&
                  (NormalizeDouble(OrderStopLoss() - Ask,Digits) > NormalizeDouble(chandelier_short - Ask,Digits)))
                 {
                  if(
                     OrderModify(
                        OrderTicket(),
                        OrderOpenPrice(),
                        chandelier_short,
                        OrderTakeProfit(),
                        OrderExpiration(),
                        clrNONE) == false)
                    {
                    }
                 }
           }
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double haClose(string sym, int Per, int Shift)
  {
   return (Open[Shift] +High[Shift]+ Low[Shift] + Close[Shift])/4;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double haOpen(string sym, int Per, int Shift)
  {
   double haopen5 = (Open[Shift] + haClose(sym, Per, Shift+5)) / 2;
   double haopen4 = (haopen5 + haClose(sym, Per, Shift+5)) / 2;
   double haopen3 = (haopen4 + haClose(sym, Per, Shift+4)) / 2;
   double haopen2 = (haopen3 + haClose(sym, Per, Shift+3)) / 2;
   double haopen1 = (haopen2 + haClose(sym, Per, Shift+2)) / 2;
   return (haopen1 + haClose(sym, Per, Shift+1)) / 2 ;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double haHigh(string sym, int Per, int Shift)
  {
   return MathMax(High[Shift],MathMax(haOpen(sym, Per, Shift),haClose(sym, Per, Shift)));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double haLow(string sym, int Per, int Shift)
  {
   return MathMin(Low[Shift],MathMin(haOpen(sym, Per, Shift),haClose(sym, Per, Shift)));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isGreenHeiki(string sym, int Per, int Shift)
  {
   return haOpen(sym, Per, Shift)<haClose(sym, Per, Shift);
  }

bool isRedHeiki(string sym, int Per, int Shift)
  {
   return haOpen(sym, Per, Shift)>haClose(sym, Per, Shift);
  }

//Technical analysis of the indicators
bool CrossToOpenBuy=false;
bool CrossToOpenSell=false;
bool CrossToCloseBuy=false;
bool CrossToCloseSell=false;
bool CrossToCloseHalfBuy=false;
bool CrossToCloseHalfSell=false;

double iSMMA(double& data_array[], int ma_period, int shift=0)
{
    ma_period = 2 * ma_period - 1;
    int sz=0,h=1,i=0;
    double EMA=0,aValue=0,sum=0;
    sz = ArrayRange(data_array,0);
    i = shift;
    if(i < sz && sz > 0 && ma_period > 0 && (shift + ma_period) < sz)//just some reality checks
       {    
           //calculate average for x period prior to the target shift.
           for (int j = 0; j < ma_period; j++)
           {
            sum += data_array[j];
           }
           EMA = sum / ma_period; // First SMA
           
           // SMA for later values
           i = shift + ma_period;
           while(i > shift && shift >= 0)
           { 
           //William Roeder's formula: "C = P+(V-P) * 2/(n+1)" i.e. Exponential moving average = previous EMA + [ (close - previous EMA) * 2/(n+1) ]
           EMA = EMA + ( (data_array[i] - EMA) * (2.0/(ma_period + 1)));
           i--;
           }
                           
           aValue = EMA;   
       }     
           
    return(aValue);
}

double iSMA(double& data_array[], int ma_period, int shift=0)
{
    int sz=0,h=1,i=0;
    double aValue=0,sum=0;
    sz = ArrayRange(data_array,0);
    if(i < sz && sz > 0 && ma_period > 0 && (shift + ma_period) < sz)//just some reality checks
       {    
           //sum of price in ma_period
           for (int j = 0; j < ma_period; j++)
           {
            sum += data_array[j + shift];
           }
           //Print(StringFormat("%G %G", sum, iMA(Symbol(),0,5,3,MODE_SMA,PRICE_MEDIAN,0)));
       }
    return sum / ma_period;
}

double HeikinMedian[32];

void CheckStochCross(){
   CrossToOpenBuy=false;
   CrossToOpenSell=false;
   CrossToCloseBuy=false;
   CrossToCloseSell=false;
   CrossToCloseHalfBuy=false;
   CrossToCloseHalfSell=false;
   
   for(int i = 0;i < 32;i++) {
      HeikinMedian[i] = (haHigh(Symbol(),0,i+1) + haLow(Symbol(),0,i+1)) / 2;
      //HeikinMedian[i] = (High[i] + Low[i]) / 2;
   }
   
   //double jaw2 = iMA(Symbol(),0,13,0,MODE_SMA,PRICE_MEDIAN,0);
   //double teeth2 = iMA(Symbol(),0,8,0,MODE_SMA,PRICE_MEDIAN,0);
   //double lips2 = iMA(Symbol(),0,5,0,MODE_SMA,PRICE_MEDIAN,0);
   double jaw = iSMA(HeikinMedian, 13, 8);
   double teeth = iSMA(HeikinMedian, 8, 5);
   double lips = iSMA(HeikinMedian, 5, 3);
   
   //Print(StringFormat("HA: %G %G", jaw, jaw2));
   //Print(StringFormat("Teeth: %G %G", teeth, teeth2));
   //Print(StringFormat("Lips: %G %G", lips, lips2));
   
   //Print(StringFormat("%G %G", lips, jaw2));
   
   if(jaw<teeth && teeth<lips && jaw<lips &&
   isGreenHeiki(Symbol(),0,2)==True && isGreenHeiki(Symbol(),0,1)==True
   ){
      CrossToOpenBuy=true;
   }
   if(jaw>teeth && teeth>lips && jaw>lips &&
   isGreenHeiki(Symbol(),0,2)==False && isGreenHeiki(Symbol(),0,1)==False
   ){
      CrossToOpenSell=true;
   }
   
   
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

   if (jaw>teeth || teeth>lips || jaw>lips ||
   Close[1] < SLPrice || Close[1] > TPPrice
   )
   {
      CrossToCloseBuy=true;   
   }
   if (jaw<teeth || teeth<lips || jaw<lips ||
   Close[1] > SLPrice || Close[1] < TPPrice
   )
   {
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
//Calling initialization, checks and technical analysis
   Initialize();
   CheckCanOrder();
   CheckStochCross();
   if(LastActionTime != Time[0])
     {
      if(CrossToCloseBuy)
      CloseAll(OP_BUY);
   if(CrossToCloseSell)
      CloseAll(OP_SELL);
   if(CrossToOpenBuy)
     {
      if(CanOpenBuy && CanOrder)
         OpenNew(OP_BUY);
     }
   if(CrossToOpenSell)
     {
      if(CanOpenSell && CanOrder)
         OpenNew(OP_SELL);
     }
      
      TrailingSL();
      LastActionTime = Time[0];
     }
//Check of Entry/Exit signal with operations to perform
   //if(CrossToCloseHalfBuy)
   //   CloseHalf(OP_BUY);
   //if(CrossToCloseHalfSell)
   //   CloseHalf(OP_SELL);
   
  }
//+------------------------------------------------------------------+
