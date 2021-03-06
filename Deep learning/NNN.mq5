//+------------------------------------------------------------------+
//|                                                          NNN.mq5 |
//|                                                        BinaryDog |
//|                                                                  |
//+------------------------------------------------------------------+



input uint Mode = 0;

// Indicator Parameters
input ENUM_MA_METHOD MAMode = 0;
input int MAPeriod = 20;
input int RSIPeriod = 14;
input int BuyWhenProbabilityIs = 80;
input int SellWhenProbabilityIs = 80;
input bool SaveModelEveryDay = false;

/*

   EJEMPLO BASE DE RED NEURONAL PROFUNDA (NO CONVOLUCIONAL) PARA TRADING ALGORÍTMICO
   LISTO PARA USAR UNA BASE DE CONOCIMIENTOS DE 3002 NEURONAS ENTRENADAS

   Mode 0: Entrena nuevo modelo y entra en modo aprendizaje sin operar
   Mode 1: Entrena nuevo modelo y entra en modo aprendizaje operando
   Mode 2: Carga un modelo anteriormente guardado y entra en modo aprendizaje sin operar
   Mode 3: Carga un modelo anteriormente guardado y entra en modo aprendizaje operando

*/

#define Number_inputs 914
#define Number_outputs 2      // Number neurons output
#define Number_Hidden1 1500   // Number neurons hidden layer 1
#define Number_Hidden2 1500   // Number neurons hidden layer 2
#define Number_BarsResult 50
#define learningCoefficient 0.005
#define e 2.71828182
#define NumberBarsBuffer 300
#define NumberCountMA 10
                  
ulong neurons = Number_Hidden1+ Number_Hidden2 + Number_outputs;

ulong parameters = Number_inputs*Number_Hidden1
                  +Number_Hidden1*Number_Hidden2
                  +Number_Hidden2*Number_outputs
                  +neurons;

double layer1Data[Number_Hidden1][Number_inputs+1],// = {{3.456078,3.381466,-1.973136}, {3.472539,3.225385,-1.946369}, {-0.199374,4.025186,-2.279149}},
       layer2Data[Number_Hidden2][Number_Hidden1+1],//  = {{-3.313430,-0.854174,-0.163974,1.214439},{-3.047598,-3.430066,-0.228030,2.628650},{-0.052599,-1.987146,-0.932982,-0.595154}},
       layer3Data[Number_outputs][Number_Hidden2+1];//  = {{0.429360,4.372813,1.997765,-2.659567}};
       
double AxisH1[Number_Hidden1]; //   Neurons outputs Hidden layer 1
double AxisH2[Number_Hidden2]; //   Neurons outputs Hidden layer 2

double inputs[Number_inputs]; // Bars inputs used for backpropagation and forwardpropagation

/* Debug
double T1[Number_outputs];  
double inputs2[Number_inputs];
double T2[Number_outputs];// = {1};
double inputs3[Number_inputs];// = {0,1};
double T3[Number_outputs];// = {0};
double inputs4[Number_inputs];// = {1,1};
double T4[Number_outputs];// = {0};
*/

double outputs[Number_outputs];

ulong dataProcessed; //Number of times Backpropagation was done
uint Aux;

bool istrading;
bool aflag;

int MAHandle, RSIHandle;

string stateBot;


bool TisActiveElementT[Number_BarsResult];
int TbarsElementT[Number_BarsResult];
double TinputsForElementT[Number_BarsResult][Number_inputs];

datetime Old_Time;
datetime New_Time;

/*
   Mode 0: Entrena nuevo modelo y entra en modo aprendizaje sin operar
   Mode 1: Entrena nuevo modelo y entra en modo aprendizaje operando
   Mode 2: Carga un modelo anteriormente guardado y entra en modo aprendizaje sin operar
   Mode 3: Carga un modelo anteriormente guardado y entra en modo aprendizaje operando

*/
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   MathSrand(GetTickCount());
   dataProcessed = 0;
   
   
   
   
   Old_Time = iTime(Symbol(), PERIOD_CURRENT, 0);
   New_Time = iTime(Symbol(), PERIOD_CURRENT, 0);
   
   
   MAHandle  = iMA(Symbol(),PERIOD_CURRENT, MAPeriod,0,MAMode,PRICE_CLOSE);
   RSIHandle = iRSI(Symbol(), PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   
   
   if(Mode == 0 || Mode == 1)
   {
      if(Mode == 0) istrading = false;
      else istrading = true;
      
      NewModel();
   }
   else{
      int loaded = LoadModel();
      if(loaded == -1) ExpertRemove();
   }
   
   
   if(istrading) stateBot = "TRADING: ON";
   else stateBot = "TRADING: OFF";
   if(Mode == 4) stateBot += "\nLEARNING: OFF";
   else stateBot += "\nLEARNING: ON";
   
   stateBot += "\nPARAMETERS: " + parameters;
   stateBot += "\nNEURONS: " + neurons;
   stateBot += "\nLEARNING COEFFICIENT: " + learningCoefficient;
   stateBot += "\nPROCESSES: " + dataProcessed;
   stateBot += "\nBUY: 0.0%";
   stateBot += "\nSELL: 0.0%";
   
   
   SaveModel();
  Comment(stateBot);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   SaveModel();
   //Print("");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //---
   
   if(!isNewBar()) return;
   else{
      for(int i = 0; i < Number_BarsResult; i++)
      {
         if(TisActiveElementT[i])
            TbarsElementT[i]++;
      }
         
   }
   
   bool ErrorIndicator = false;
   
   //--- Buffers ---
   double _MABuffer[],
          _RSIBuffer[],
          _HighsBuffer[],
          _LowsBuffer[],
          _ClosesBuffer[];
   
   ArraySetAsSeries(_MABuffer, true);
   ArraySetAsSeries(_RSIBuffer, true);       
   ArraySetAsSeries(_HighsBuffer, true);     
   ArraySetAsSeries(_LowsBuffer, true);     
   ArraySetAsSeries(_ClosesBuffer, true);
   
   // Set Buffers
   if (CopyBuffer(MAHandle,0,1,NumberCountMA,_MABuffer) < 0)  {Print("(!) CopyBuffer MainMA_Handle Error = ",GetLastError());ErrorIndicator = true;}
   //
   if (CopyBuffer(RSIHandle, 0,1,3,_RSIBuffer) < 0)   {Print("(!) CopyBuffer RSI_Handle Error = ",GetLastError());   ErrorIndicator = true;}
   //
   if (CopyHigh(Symbol(),PERIOD_CURRENT, 1,NumberBarsBuffer, _HighsBuffer) < 0){Print("(!) CopyHigh Historical Data Error = ",GetLastError());ErrorIndicator = true;}
   //
   if (CopyLow(Symbol(), PERIOD_CURRENT, 1,NumberBarsBuffer, _LowsBuffer) < 0) {Print("(!) CopyLow Historical Data Error = ",GetLastError());ErrorIndicator = true;}
   //
   if (CopyClose(Symbol(),PERIOD_CURRENT,1, NumberBarsBuffer, _ClosesBuffer) < 0){Print("(!) CopyClose Historical Data Error = ",GetLastError());ErrorIndicator = true;}
   
   // MA[] { 0,   1,    2}
   //        ^ Current bar -> Position 0
   //             ^ Previous bar -> Position 1
   
   if(ErrorIndicator){ Print("Error Indicator: ", GetLastError()); ResetLastError(); return;}
   
   //---
   
   // Set inputs from the bars and indicators
   TransformDataAndSetInputs(_MABuffer,_RSIBuffer,_ClosesBuffer,_HighsBuffer,_LowsBuffer);
   
   // Backpropagation
   for(int i = 0; i < Number_BarsResult; i++)
   {
      if(TbarsElementT[i] == Number_BarsResult)
      {
         double T[Number_outputs];
         double outss[Number_outputs];
         double tempInputs[Number_inputs];
         
         CalculateTArray(T,_HighsBuffer,_LowsBuffer,_ClosesBuffer);
         
         for(int j = 0; j < Number_inputs; j++) tempInputs[j] = TinputsForElementT[i][j];
         
         forwardPropagation(tempInputs, AxisH1, AxisH2, outss);
         backPropagation(tempInputs, AxisH1, AxisH2, outss, T);
         
         TbarsElementT[i] = 0;
         TisActiveElementT[i] = false;
         Aux++;
         if(Aux == 1000) { dataProcessed++; Aux = 0; }
         
      }
   }
   
   // ForwardPropagation
   for(int i = 0; i < Number_BarsResult; i++)
   {
      if(!TisActiveElementT[i])
      {
         TisActiveElementT[i] = true;
         TbarsElementT[i] = 0;
         
         for(int j = 0; j < Number_inputs; j++)
         {
            TinputsForElementT[i][j] = inputs[j];
         }
         
         forwardPropagation(inputs,AxisH1,AxisH2,outputs);
         break;
      }
   }
   
   
   
   
   outputs[0] = NormalizeDouble(outputs[0],4);
   outputs[1] = NormalizeDouble(outputs[1],4);
   
   //---
   if(istrading) stateBot = "TRADING: ON";
   else stateBot = "TRADING: OFF";
   if(Mode == 4) stateBot += "\nLEARNING: OFF";
   else stateBot += "\nLEARNING: ON";
   
   stateBot += "\nPARAMETERS: " + parameters;
   stateBot += "\nNEURONS: " + neurons;
   stateBot += "\nLEARNING COEFFICIENT: " + learningCoefficient;
   stateBot += "\nPROCESSES: " + dataProcessed + "*1000";
   stateBot += "\nBUY: " + outputs[0];
   stateBot += "\nSELL: " + outputs[1];
   
   Comment(stateBot);
   
}
//+------------------------------------------------------------------+
void CalculateTArray(double &T[], double &HighBuffer[], double &LowBuffer[], double &CloseBuffer[])
{
   
   double maxPre  = HighBuffer[ArrayMaximum(HighBuffer, 1, NumberBarsBuffer)];
   double minPre  = LowBuffer[ArrayMinimum(LowBuffer, 1, NumberBarsBuffer)];
   double difPre  = maxPre - minPre;
   
   double maxPost = HighBuffer[ArrayMaximum(HighBuffer, 1, Number_BarsResult)];
   double minPost = LowBuffer[ArrayMinimum(LowBuffer, 1, Number_BarsResult)];
   double difPost = maxPost - minPost;
   double open = CloseBuffer[Number_BarsResult];
   
   // Buy
   T[0] = (MathAbs(maxPost - open)) / difPre;
   // Sell
   T[1] = (MathAbs(minPost - open)) / difPre;
   
}
//+------------------------------------------------------------------+
bool isNewBar()
{
   New_Time = iTime(Symbol(),PERIOD_CURRENT, 0);
   
   if(New_Time != Old_Time) 
   {
      Old_Time = New_Time;
      return true; 
   }
   else return false;
}
//+------------------------------------------------------------------+
void TransformDataAndSetInputs(double &MABuffer[],
                   double &RSIBuffer[],
                   double &ClosesBuffer[],
                   double &HighsBuffer[],
                   double &LowsBuffer[])
{
   datetime tm = TimeCurrent();
   MqlDateTime stm;
   TimeToStruct(tm,stm);

   double max;
   double min;
   double dif;
   
   int indexInput = 0;
   
   max = HighsBuffer[ArrayMaximum(HighsBuffer, 1, NumberBarsBuffer)];
   min = LowsBuffer[ArrayMinimum(LowsBuffer, 1, NumberBarsBuffer)];
   dif = max - min;
   
   
   // Transform bars and set
   for(int i = 0; i < NumberBarsBuffer; i++)
   {
      inputs[indexInput] = MathAbs(((max - HighsBuffer[i]) / dif) - 1);
      indexInput++;
      inputs[indexInput] = MathAbs(((max - LowsBuffer[i]) / dif) - 1);
      indexInput++;
      inputs[indexInput] = MathAbs(((max - ClosesBuffer[i]) / dif) - 1);
      indexInput++;
   }
   
   // Transform and Reg MA
   for(int i = 0; i < NumberCountMA; i++)
   {
      inputs[indexInput] = MathAbs(((max - MABuffer[i]) / dif) - 1);
      indexInput++;
   }
   
   inputs[indexInput] = RSIBuffer[0];
   indexInput++;
   inputs[indexInput] = RSIBuffer[1];
   indexInput++;
   
   
   inputs[indexInput] = stm.day_of_week;
   indexInput++;
   inputs[indexInput] = stm.hour;
   indexInput++;
}

//+------------------------------------------------------------------+
class TestElement
{
   private:
      int bars;
      bool active;
      
   public:
      double inputsT[Number_inputs];
      TestElement(bool Active) { bars = 0; active = Active; }
};
//+------------------------------------------------------------------+
void forwardPropagation(double &ins[],
                        double &AxisHidden1[],
                        double &AxisHidden2[],
                        double &outs[])
{
   // Layer 1
   for(int i = 0; i < Number_Hidden1; i++)
   {
      double A = 0;
      for(int j = 0; j < Number_inputs; j++)
      {
         A += ins[j]*layer1Data[i][j];
      }
      AxisHidden1[i] = Sigmoid(A+layer1Data[i][Number_inputs]);
   }
   
   // Layer 2
   for(int i = 0; i < Number_Hidden2; i++)
   {
      double A = 0;
      for(int j = 0; j < Number_Hidden1; j++)
      {
         A += AxisHidden1[j]*layer2Data[i][j];
      }
      AxisHidden2[i] = Sigmoid(A+layer2Data[i][Number_Hidden1]);
   }
   
   // Layer 3
   for(int i = 0; i < Number_outputs; i++)
   {
      double A = 0;
      for(int j = 0; j < Number_Hidden2; j++)
      {
         A += AxisHidden2[j]*layer3Data[i][j];
      }
      outs[i] = Sigmoid(A+layer3Data[i][Number_Hidden2]);
   }
   
   
}
//+------------------------------------------------------------------+
void backPropagation(double &ins[],
                     double &AxisHidden1[],
                     double &AxisHidden2[],
                     double &outs[],
                     double &T[])
{
   double deltaI[Number_Hidden1],
          deltaJ[Number_Hidden2],
          deltaK[Number_outputs];
//*
   //for(int i = 0; i < Number_Hidden1; i++) Print("AxisH1 ", i, ": ", AxisHidden1[i]);
   //for(int i = 0; i < Number_Hidden2; i++) Print("AxisH2 ", i, ": ", AxisHidden2[i]);
   //for(int i = 0; i < Number_outputs; i++) Print("AxisOu ", i, ": ", AxisHidden2[i]);

          
   double Error[Number_outputs],
          prodTempJ[Number_Hidden2],
          prodTempI[Number_Hidden1];
          
   double sumj = 0, sumi = 0;       
          
   for (int i = 0; i < Number_Hidden1; i++) prodTempI[i] = 0;
   for (int i = 0; i < Number_Hidden2; i++) prodTempJ[i] = 0;
   
   for (int i = 0; i < Number_outputs; i++) Error[i] = T[i] - outs[i];
   
   for (int i = 0; i < Number_outputs; i++) deltaK[i] = (outs[i] * (1 - outs[i])) * Error[i];
   
   
   for (int j = 0; j < Number_Hidden2; j++)
   {
      for (int k = 0; k < Number_outputs; k++)
      {
         prodTempJ[j] += layer3Data[k][j] * deltaK[k];
      }
   }
   
   for (int i = 0; i < Number_Hidden2; i++) sumj += prodTempJ[i];
   
   for (int i = 0; i < Number_Hidden2; i++) deltaJ[i] = sumj * (AxisHidden2[i] * (1 - AxisHidden2[i]));
   
   
   for (int i = 0; i < Number_Hidden1; i++) 
   {
		for (int j = 0; j < Number_Hidden2; j++) 
		{
			prodTempI[i] += layer2Data[j][i] * deltaJ[j];
		}
	}
	
	for (int i = 0; i < Number_Hidden2; i++) sumi += prodTempI[i];
	
	for (int i = 0; i < Number_Hidden2; i++) deltaI[i] = sumi * (AxisHidden1[i] * (1 - AxisHidden1[i]));
	
	
   //	Actualizar conocimiento
	//	Layer Hidden 1
	for (int i = 0; i < Number_Hidden1; i++) {
		double AlphaDelta = learningCoefficient * deltaI[i];
		for (int j = 0; j < Number_inputs; j++) {
			//layers[0].neuron[i].W[j] += AlphaDelta * inputs[j];
			layer1Data[i][j] += AlphaDelta * ins[j];
		}
		//layers[0].neuron[i].B += AlphaDelta;
		layer1Data[i][Number_inputs] += AlphaDelta;
	}
	
	//	Layer Hidden 2
	for (int i = 0; i < Number_Hidden2; i++) {
		double AlphaDelta = learningCoefficient * deltaJ[i];
		for (int j = 0; j < Number_Hidden1; j++) {
			//layers[0].neuron[i].W[j] += AlphaDelta * inputs[j];
			layer2Data[i][j] += AlphaDelta * AxisHidden1[j];
		}
		//layers[0].neuron[i].B += AlphaDelta;
		layer2Data[i][Number_Hidden1] += AlphaDelta;
	}
	
	//	Layer Hidden 3
	for (int i = 0; i < Number_outputs; i++) {
		double AlphaDelta = learningCoefficient * deltaK[i];
		for (int j = 0; j < Number_Hidden2; j++) {
			//layers[0].neuron[i].W[j] += AlphaDelta * inputs[j];
			layer3Data[i][j] += AlphaDelta * AxisHidden2[j];
		}
		//layers[0].neuron[i].B += AlphaDelta;
		layer3Data[i][Number_Hidden2] += AlphaDelta;
	}
          
}

//+------------------------------------------------------------------+
int LoadModel()
{
   Print("(!) Loading Model...");
       
   int filehandle = FileOpen("NNData"+ Symbol() +".dat",FILE_READ|FILE_BIN);
   int fileHandleprocessed = FileOpen("Datax" + Symbol() +".dat",FILE_READ|FILE_BIN);
   
   if(fileHandleprocessed != INVALID_HANDLE) dataProcessed = FileReadLong(fileHandleprocessed);
   
   if(filehandle == INVALID_HANDLE)
   {
      Print("(X) Error loading Model: ", GetLastError());
      return -1;
   }
   
   //---
   for(int i = 0; i < Number_Hidden1; i++)
   {
      for(int j = 0; j < Number_inputs; j++)
      {
         layer1Data[i][j] = FileReadDouble(filehandle);
      }
      layer1Data[i][Number_inputs] = FileReadDouble(filehandle);
   }
   //---
   for(int i = 0; i < Number_Hidden2; i++)
   {
      for(int j = 0; j < Number_Hidden1; j++)
      {
         layer2Data[i][j] = FileReadDouble(filehandle);
      }
      layer2Data[i][Number_Hidden1] = FileReadDouble(filehandle);
   }
   //---
   for(int i = 0; i < Number_outputs; i++)
   {
      for(int j = 0; j < Number_Hidden2; j++)
      {
         layer3Data[i][j] = FileReadDouble(filehandle);
      }
      layer3Data[i][Number_Hidden2] = FileReadDouble(filehandle);
   }
   
   
   FileClose(filehandle);
   Print("Model loaded successfully.");
   return 1;
}
//+------------------------------------------------------------------+
void SaveModel()
{
   Print("(!) Saving model... Please do not close the terminal");
   
   // 128 Parameter per KB
   int filehandle = FileOpen("NNData"+ Symbol() +".dat",FILE_READ|FILE_WRITE|FILE_BIN);
   int fileHandleprocessed = FileOpen("Datax" + Symbol() +".dat",FILE_READ|FILE_WRITE|FILE_BIN);
   
   if(fileHandleprocessed != INVALID_HANDLE) FileWriteLong(fileHandleprocessed, dataProcessed);
   //---
   for(int i = 0; i < Number_Hidden1; i++)
   {
      for(int j = 0; j < Number_inputs; j++)
      {
         FileWriteDouble(filehandle,layer1Data[i][j]);
      }
      FileWriteDouble(filehandle,layer1Data[i][Number_inputs]);
   }
   //---
   for(int i = 0; i < Number_Hidden2; i++)
   {
      for(int j = 0; j < Number_Hidden1; j++)
      {
         FileWriteDouble(filehandle,layer2Data[i][j]);
      }
      FileWriteDouble(filehandle,layer2Data[i][Number_Hidden1]);
   }
   //---
   for(int i = 0; i < Number_outputs; i++)
   {
      for(int j = 0; j < Number_Hidden2; j++)
      {
         FileWriteDouble(filehandle,layer3Data[i][j]);
      }
      FileWriteDouble(filehandle,layer3Data[i][Number_Hidden2]);
   }
   //---
   FileClose(filehandle);
   Print("Model saved successfully.");
}
//+------------------------------------------------------------------+
void NewModel()
{
   Print("(!) Creating a new model");
   
   for(int i = 0; i < Number_Hidden1; i++)
   {
      for(int j = 0; j < Number_inputs; j++)
      {
         layer1Data[i][j] = RandomNumber(-2,2);
      }
      layer1Data[i][Number_inputs] = RandomNumber(-2,2);
   }
   //---
   for(int i = 0; i < Number_Hidden2; i++)
   {
      for(int j = 0; j < Number_Hidden1; j++)
      {
         layer2Data[i][j] = RandomNumber(-2,2);
      }
      layer2Data[i][Number_Hidden1] = RandomNumber(-2,2);
   }
   //---
   for(int i = 0; i < Number_outputs; i++)
   {
      for(int j = 0; j < Number_Hidden2; j++)
      {
         layer3Data[i][j] = RandomNumber(-2,2);
      }
      layer3Data[i][Number_Hidden2] = RandomNumber(-2,2);
   }
   
   Print("Created model");
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
double RandomNumber(int from, int to){
   
   long temp = to - from;
   double f = (double)MathRand() / 32767;
   double ret = from + f * (temp);
   return ret;
}

double Sigmoid(double x) {
	return 1 / (1 + pow(e, -x));
}