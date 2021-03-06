//+------------------------------------------------------------------+
//|                                                        Trend.mq4 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, victor"
#property link      "https://www.mql5.com"
#property version   "1.04"

#include <hash.mqh>

static int MaxOrders=4;
extern double MaxRisk=1;//资金风险1=1%

static int STO_PERIOD_M15= 8;
static int STO_PERIOD_H1 = 5;

#define MACROSS_OPEN_BUY_SIGNAL 1
#define MACROSS_OPEN_SELL_SIGNAL -1
#define MACROSS_NO_SIGNAL 0

int       ShortMaPeriod = 10;
int       LongMaPeriod  = 20;

Hash *map = new Hash();

string GBPUSD = "GBPUSD";
string EURUSD = "EURUSD";
string USDJPY = "USDJPY";
string USDCAD = "USDCAD";
string AUDUSD = "AUDUSD";


bool ProcedTrailing=true; // 是否启动移动止损止盈
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum STATE
  {
   BULL,
   BEAR,
   SWING
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getLotsOptimized(double RiskValue)
  {
//最大可开仓手数  ？最好用净值 不要用余额
   double iLots=NormalizeDouble((AccountBalance()*RiskValue/100/MarketInfo(Symbol(),MODE_MARGINREQUIRED)),2);

   if(iLots<0.01)
     {
      iLots=0;
      Print("保证金余额不足");
     }

   return iLots;
   //return 1.0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止损(短线交易)
 */
int getStopLoss_s(string symbol)
  {
   int stopLoss = 15;
   if(symbol==GBPUSD || symbol==USDCAD)
     {
      stopLoss = 20;
     }

   return stopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止盈(短线交易)
 */
int getTakeProfit_s(string symbol)
  {
   int takeprofit = 20;
   if(symbol==GBPUSD || symbol==USDCAD)
     {
      takeprofit = 30;
     }

   return takeprofit;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止损(中线交易)
 */
int getStopLoss_m(string symbol)
  {
   int stopLoss=20;
   if(symbol==GBPUSD || symbol==USDCAD)
     {
      stopLoss=25;
     }

   return stopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止损(中线交易)
 */
int getTakeProfit_m(string symbol)
  {
   int takeprofit=25;
   if(symbol==EURUSD || symbol==GBPUSD || symbol==USDJPY)
     {
      takeprofit=30;
     }

   return takeprofit;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
 *  返回值 :
 *      -1 - 下单失败 0 - 订单已存在 其它 - 订单号 
 */
int iOpenOrders(string myType,double myLots,int myLossStop,int myTakeProfit,string comment)
  {

// 检查相同货币对是否已经下单
   bool isOrderOpen=false;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if((OrderComment()==comment))
           {
            isOrderOpen=true;
            return 0;
           }
        }
     }

   double UsePoint = getPipPoint(Symbol());

   int ticketNo=-1;
   int mySpread=MarketInfo(Symbol(),MODE_SPREAD);//点差 手续费 市场滑点
   double sl_buy=(myLossStop<=0)?0:(Ask-myLossStop*UsePoint);
   double tp_buy=(myTakeProfit<=0)?0:(Ask+myTakeProfit*UsePoint);
   double sl_sell=(myLossStop<=0)?0:(Bid+myLossStop*UsePoint);
   double tp_sell=(myTakeProfit<=0)?0:(Bid-myTakeProfit*UsePoint);

   if(myType=="Buy")
      ticketNo=OrderSend(Symbol(),OP_BUY,myLots,Ask,mySpread,sl_buy,tp_buy,comment);
   if(myType=="Sell")
      ticketNo=OrderSend(Symbol(),OP_SELL,myLots,Bid,mySpread,sl_sell,tp_sell,comment);

   return ticketNo;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
 * 平仓 关闭指定货币对订单
 */
void iCloseOrder(string symbol) 
  {

   int cnt=OrdersTotal();
   int mySpread=MarketInfo(Symbol(),MODE_SPREAD);

   if(OrderSelect(cnt-1,SELECT_BY_POS)==false)
      return;

   for(int i=cnt-1; i>=0; i--) 
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) 
        {
         if(OrderComment()==symbol) 
           {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(), mySpread)) 
               Print("OrderClose error ",GetLastError());
           }
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
 * 查询当前货币对订单数
 */

int getOrderCount(string symbol)
  {
   int count = 0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol())
        {
         count++;
        }
     }
//--- return orders volume
   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void iCloseOrders(string myType)
  {
   int cnt=OrdersTotal();
   int i;
//选择当前持仓单
   if(OrderSelect(cnt-1,SELECT_BY_POS)==false)return;
   if(myType=="All")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError()); 
           }
        }
     }
   else if(myType=="Buy")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else if(OrderType()==OP_BUY && OrderSymbol() == Symbol()) {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
           }
        }
     }
   else if(myType=="Sell")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS) == false)continue;
         else if((OrderType() == OP_SELL) && (OrderSymbol() == Symbol())){
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
         }
        }
     }
   else if(myType=="Profit")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else if(OrderProfit()>0){
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
         }
        }
     }
   else if(myType=="Loss")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else if(OrderProfit()<0) {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
         }
        }
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
      delete map;

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
// 已经达到最大订单数
   if(OrdersTotal() >= MaxOrders)
     {
      return;
     }

   if(getOrderCount(Symbol()) >= 1) 
     {
      // 移动止损止盈
      if(ProcedTrailing) 
        {
         ProcessTrailing();
        }
      return;
     }

// 短线交易
   if(Period()==PERIOD_M5 || Period()==PERIOD_M15) 
     {
      shortTermTradeUsingMA();
     }

// 中线交易
   if(Period()==PERIOD_M5 || Period()==PERIOD_M15) 
     {
      midTermTrade();
     }



  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessTrailing() 
  {
   int initTrailing = 17;
   double stoploss ;
   double takeprofit;
   double pip = getPipPoint(Symbol());
   string orderTicket = "";
   int trail = -1;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if((OrderType()==OP_BUY) && (Symbol()==OrderSymbol()))
           {
            stoploss = OrderStopLoss();
            takeprofit = OrderTakeProfit();
            
            orderTicket = IntegerToString(OrderTicket());
            
            trail = map.hGetInt(orderTicket);
            if(trail == -1) {
               trail = initTrailing;
               stoploss += initTrailing * pip;
               
            } else if(trail >= initTrailing) {
               return;
               trail += 5;
               stoploss += 5 * pip;
            } else {
               return;
            }
            
            takeprofit += 5 * pip;
            
            if(((Bid - OrderOpenPrice())/pip) >= trail)
              {
               
               if(OrderModify(OrderTicket(),OrderOpenPrice(),stoploss,takeprofit,0)==true)
                 {
                  Print("Order: ", OrderTicket(), "New stoploss:", stoploss);
                  map.hPutInt(orderTicket, trail);
                 }
              }
           }
         if((OrderType()==OP_SELL) && ((Symbol()==OrderSymbol())))
           {
            stoploss = OrderStopLoss();
            takeprofit = OrderTakeProfit();
            orderTicket = IntegerToString(OrderTicket());
            
            trail = map.hGetInt(orderTicket);
            if(trail == -1) {
               trail = initTrailing;
               stoploss -= initTrailing * pip;
               
            } else if(trail >= initTrailing) {
               return;
               trail += 5;
               stoploss -= 5 * pip;
            } else {
               return;
            }
            takeprofit -= 5 * pip;
            
            if(((OrderOpenPrice()-Ask)/pip) >= trail)
              {
               double sellsl = OrderStopLoss();
               if(OrderModify(OrderTicket(),OrderOpenPrice(),stoploss,takeprofit,0) == true)
                 {
                  Print("Order: ", OrderTicket(), "New stoploss:", stoploss);
                  map.hPutInt(orderTicket, trail);
                 }
              }
           }
        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void shortTermTrade() 
  {

   bool flag=Symbol()==EURUSD || Symbol()==GBPUSD || 
             Symbol()==USDJPY || Symbol()==AUDUSD;

   if(!flag) return;

   STATE st1 = getTrend(1);
   STATE st2 = getTrend(2);
   STATE st3 = getTrend(3);

   int stopLoss=15;
   int takeProfit=20;
   double lots=0.0;
   double discrimination=0.0;

   double open0=iClose(Symbol(),0,0);
   double open1=iClose(Symbol(),0,1);
   double open2=iClose(Symbol(),0,2);

   if(st1==st2 && st2==st3) 
     {
      return;

     }

   if(st1!=st2 && st2==st3) 
     {

      if(st1==BULL) 
        {

         if(getOrderCount(Symbol()) >= 1) return;

         discrimination=MathAbs(open0-open1);


         if(discrimination / 0.00001 >= 15) 
            return; 

         if(Symbol()==EURUSD || Symbol()==GBPUSD || Symbol()==USDJPY) 
           {

           // if( !checkDemarker(1, STO_PERIOD_M15)) return;

            stopLoss=getStopLoss_s(Symbol());
            takeProfit=getTakeProfit_s(Symbol());

            Print("Stop Loss:",stopLoss);
            Print("Take profit:",takeProfit);

            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Buy",lots,stopLoss,takeProfit,Symbol());

              } else {
            //if( !checkSto(1, STO_PERIOD_M15)) return;

            stopLoss=getStopLoss_s(Symbol());
            takeProfit=getTakeProfit_s(Symbol());
            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Buy",lots,stopLoss,takeProfit,Symbol());

           }



           } else if(st1==BEAR) {

         if(getOrderCount(Symbol()) >= 1) return;

         discrimination=MathAbs(open0-open1);


         if(discrimination / 0.00001 >= 15) 
            return; 

         if(Symbol()==EURUSD || Symbol()==GBPUSD || Symbol()==USDJPY) 
           {

           // if( !checkDemarker(2, STO_PERIOD_M15)) return;

            stopLoss = getStopLoss_s(Symbol());
            takeProfit = getTakeProfit_s(Symbol());
            lots = getLotsOptimized(MaxRisk);

            iOpenOrders("Sell",lots,stopLoss,takeProfit,Symbol());

              } else {
           // if( !checkSto(2, STO_PERIOD_M15)) return;

            stopLoss=getStopLoss_s(Symbol());
            takeProfit=getTakeProfit_s(Symbol());
            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Sell",lots,stopLoss,takeProfit,Symbol());

           }

        }

     }

  }
  

/**
 * Get moving average values for the most recent price points.
 * 
 * Params:
 * maPeriod: period of the MA.
 * numValues: Number of values to insert into the returned array.
 * ma: returned array of MA values, with ma[0] being the value for the
 *    current price, ma[1] the value for the previous bar's price, etc.
 *
 */
void MaRecentValues(double& ma[], int maPeriod, int numValues = 3)
  {
   // i is the index of the price array to calculate the MA value for.
   // e.g. i=0 is the current price, i=1 is the previous bar's price.
   for (int i=0; i < numValues; i++)
     {
      ma[i] = iMA(NULL,0,maPeriod,0,MODE_SMA,PRICE_CLOSE,i);
     }
  }

/**
 * Check if we should open a trade.
 *
 * Returns: +1 to open a buy order, -1 to open a sell order, 0 for no action.
 */
int OpenSignal()
  {
   int signal = MACROSS_NO_SIGNAL;

   // Execute only on the first tick of a new bar, to avoid repeatedly
   // opening orders when an open condition is satisfied.
   if (Volume[0] > 1) return(0);
   
   //---- get Moving Average values

   double shortMa[3];
   MaRecentValues(shortMa, ShortMaPeriod, 3);

   double longMa[3];
   MaRecentValues(longMa, LongMaPeriod, 3);
   
   //---- buy conditions
   if (shortMa[2] < longMa[2]
      && shortMa[1] > longMa[1])
     {
      signal = MACROSS_OPEN_BUY_SIGNAL;
     }

   //---- sell conditions
   if (shortMa[2] > longMa[2]
      && shortMa[1] < longMa[1])
     {
      signal = MACROSS_OPEN_SELL_SIGNAL;
     }

   //----
   return(signal);
  }
  
void shortTermTradeUsingMA() 
  {

   bool flag=Symbol()== EURUSD || Symbol() == GBPUSD || 
             Symbol()== USDJPY || Symbol() == AUDUSD;

   if(!flag) return;

   STATE trend = getTrend(1);

   int stopLoss=15;
   int takeProfit=20;
   double lots=0.0;
   double discrimination=0.0;
   int orderCount = 0;

   int signal = OpenSignal();
   
   if(signal == MACROSS_OPEN_BUY_SIGNAL) {
      //Print("Buy Order -> MA10 = ", M10, " MA20 = ", M20, "M10_ = ", prevM10, "M20_=", prevM20);
      //Print("Trend:", trend);
      
      
      orderCount = getOrderCount(Symbol());
      Print("上穿 货币对=", Symbol(), " 当前订单数 = ", orderCount);
      
      if(orderCount >= 1) {
         // 空单平仓
         Print("空单平仓");
         // iCloseOrders("Sell");
         
         return;
      }
      
   
      // 方法一 非下降趋势就进场
      if(trend != BEAR) {
         stopLoss=getStopLoss_s(Symbol());
         takeProfit=getTakeProfit_s(Symbol());
         lots = getLotsOptimized(MaxRisk);
      
         iOpenOrders("Buy",lots,stopLoss,takeProfit,Symbol());
      }
        
      
   } else if(signal == MACROSS_OPEN_SELL_SIGNAL) {
   
       Print("多单平仓");
       //iCloseOrders("Buy");
       iCloseOrder(Symbol());
      
       orderCount = getOrderCount(Symbol());
       Print("下穿 货币对=", Symbol(), " 当前订单数 = ", orderCount);
       
       if(orderCount >= 1) {
         // 多单平仓
         Print("多单平仓");
         iCloseOrders("Buy");
         return;
      }
      
      // 方法一 非上升趋势就进场
      if(trend == BULL) return;
      
      stopLoss=getStopLoss_s(Symbol());
      takeProfit=getTakeProfit_s(Symbol());
      lots=getLotsOptimized(MaxRisk);

      iOpenOrders("Sell",lots,stopLoss,takeProfit,Symbol());
      
   }
   
   
     

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void midTermTrade() 
  {

   bool flag=Symbol()==EURUSD || Symbol()==GBPUSD || 
             Symbol()==USDJPY || Symbol()==AUDUSD || Symbol()==USDCAD;

   if(!flag) return;

   STATE st1 = getTrend(1);
   STATE st2 = getTrend(2);
   STATE st3 = getTrend(3);

   int stopLoss=15;
   int takeProfit=20;
   double lots=0.0;
   double discrimination=0.0;

   double open0=iClose(Symbol(),0,0);
   double open1=iClose(Symbol(),0,1);
   double open2=iClose(Symbol(),0,2);

   if(st1==st2 && st2==st3) 
     {
      return;

     }

   if(st1!=st2 && st2==st3) 
     {

      if(st1==BULL) 
        {

         if(getOrderCount(Symbol()) >= 1) return;

         discrimination=MathAbs(open0-open1);

         if(discrimination/getPipPoint(Symbol())>=15)
            return;

         if(Symbol()==GBPUSD) 
           {

            if( !checkDemarker(1, STO_PERIOD_H1)) return;

            stopLoss=getStopLoss_m(Symbol());
            takeProfit=getTakeProfit_m(Symbol());
            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Buy",lots,stopLoss,takeProfit,Symbol());

              } else {
            if( !checkSto(1, STO_PERIOD_H1)) return;

            stopLoss=getStopLoss_m(Symbol());
            takeProfit=getTakeProfit_m(Symbol());
            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Buy",lots,stopLoss,takeProfit,Symbol());

           }



           } else if(st1==BEAR) {

         if(getOrderCount(Symbol()) >= 1) return;

         discrimination=MathAbs(open0-open1);

         if(discrimination/getPipPoint(Symbol())>=15)
            return;

         if(Symbol()==EURUSD || Symbol()==GBPUSD || Symbol()==USDJPY) 
           {

            if( !checkDemarker(2, STO_PERIOD_H1)) return;

            stopLoss=getStopLoss_m(Symbol());
            takeProfit=getTakeProfit_m(Symbol());
            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Sell",lots,stopLoss,takeProfit,Symbol());

              } else {
            if( !checkSto(2, STO_PERIOD_H1)) return;

            stopLoss=getStopLoss_m(Symbol());
            takeProfit=getTakeProfit_m(Symbol());
            lots=getLotsOptimized(MaxRisk);

            iOpenOrders("Sell",lots,stopLoss,takeProfit,Symbol());

           }

        }

     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
 * 参数 type :
 *       1 - 上穿  2 - 下穿
 */
bool checkDemarker(int type,int period) 
  {


   for(int i=0; i<period; i++) 
     {
      double dm=iDeMarker(0,0,14,i);
      double dm1=iDeMarker(0,0,14,i+1);

      if(type==1) 
        {
         if(dm1<0.3 && dm>=0.3) 
           {
            return true;
           }
           } else if(type==2) {
         if(dm1>0.7 && dm<=0.7) 
           {
            return true;
           }
        }

     }

   return false;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
 * 参数 type :
 *       1 - 上穿  2 - 下穿
 */
bool checkSto(int type,int period) 
  {

   for(int i=0; i<period; i++) 
     {
      double stochastic=iStochastic(NULL,PERIOD_M15,8,3,3,MODE_EMA,0,MODE_MAIN,i);
      double stochastic_prev=iStochastic(NULL,PERIOD_M15,8,3,3,MODE_EMA,0,MODE_MAIN,i+1);

      if(type==1) 
        {
         if(stochastic_prev<20 && stochastic>=20) 
           {
            return true;
           }
           } else if(type==2) {
         if(stochastic_prev>80 && stochastic<=80) 
           {
            return true;
           }
        }

     }

   return false;

  }
// 两位或三位的报价 返回0.01 四位或五位报价 返回0.0001
double getPipPoint(string Currency)
  {
   int digits=(int)MarketInfo(Currency,MODE_DIGITS);
   double pips=0.0001;
   if(digits==2 || digits==3)
      pips=0.01;
   else if(digits==4 || digits==5)
      pips=0.0001;
   return pips;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
STATE getTrend(int index) 
  {
   STATE state=SWING;

   double MA10=iMA(Symbol(),0,10,0,MODE_EMA,PRICE_CLOSE,index);
   double MA20=iMA(Symbol(),0,20,0,MODE_EMA,PRICE_CLOSE,index);


// 计算基准线Kijun-sen
   double kijunsen=iIchimoku(Symbol(),0,7,22,44,MODE_KIJUNSEN,index);
   double tenkansen=iIchimoku(Symbol(),0,7,22,44,MODE_TENKANSEN,index);

   double close=iClose(Symbol(),0,index);

   if(close>=kijunsen && tenkansen>=kijunsen)
     {
      if(close >= MA10 && close >= MA20)
        {
         state=BULL;
        }
     } else if(close<kijunsen && tenkansen<kijunsen) {
      if(close<MA10 && close<MA20)
        {
         state=BEAR;
        }
        } else {
         state=SWING;
     }

   return state;
  }
//+------------------------------------------------------------------+

bool isTrendChange(int cur,int prev)
  {

   STATE curState=SWING;
   STATE prevState=SWING;

   double MA10=iMA(Symbol(),0,10,0,MODE_EMA,PRICE_CLOSE,cur);
   double prevMA10=iMA(Symbol(),0,10,0,MODE_EMA,PRICE_CLOSE,prev);
   double MA20=iMA(Symbol(),0,20,0,MODE_EMA,PRICE_CLOSE,cur);
   double prevMA20=iMA(Symbol(),0,20,0,MODE_EMA,PRICE_CLOSE,prev);

// 计算基准线Kijun-sen
   double kijunsen=iIchimoku(Symbol(),0,7,22,44,MODE_KIJUNSEN,cur);
   double prevKijunsen=iIchimoku(Symbol(),0,7,22,44,MODE_KIJUNSEN,prev);
   double tenkansen=iIchimoku(Symbol(),0,7,22,44,MODE_TENKANSEN,cur);
   double prevTenkansen=iIchimoku(Symbol(),0,7,22,44,MODE_TENKANSEN,prev);

   double close=iClose(Symbol(),0,cur);
   double prevClose=iClose(Symbol(),0,prev);

   if(close>=kijunsen && tenkansen>=kijunsen)
     {
      if(close>MA10 && close>MA20)
        {
         curState=BULL;
        }
        } else if(close<kijunsen && tenkansen<kijunsen) {
      if(close<MA10 && close<MA20)
        {
         curState=BEAR;
        }
        } else {
      curState=SWING;
     }

   if(prevClose>=prevKijunsen && prevTenkansen>=prevKijunsen)
     {
      if(prevClose>prevMA10 && prevClose>prevMA20)
        {
         prevState=BULL;
        }
        }else if(prevClose<prevKijunsen && prevTenkansen<prevKijunsen) {
      if(prevClose<prevMA10 && prevClose<prevMA20)
        {
         prevState=BEAR;
        }
        } else {
      prevState=SWING;
     }

   if(curState!=prevState)
     {
      return true;
     }

   return false;

  }
//+------------------------------------------------------------------+
