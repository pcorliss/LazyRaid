#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ruby.h>
#include "jerasure.h"
#include "liberation.h"

static VALUE rb_mParity;

static int erasedCheck(int disk, int *erasures){
  int i = 0;
  for(i=0;erasures[i] != -1;i++){
    if(erasures[i] == disk){
      printf("%d:ERASED\n",disk);
      return 1;
    }
  }
  printf("%d:GOOD\n",disk);
  return 0;
}

static void outputData(int disk,char *data,int length){
  int i=0;
  int j=0;
  /*for(i=0;i<length;i+=16){
    printf("%d:%d:",disk,i);
    for(j=i;j<length && j < i+16;j++){
      printf("%d ",data[j]);
    }
    printf("\n");
  }*/
  for(i=0;i<length;i++){
    j+=data[i];
  }
  printf("SUMSUMSUM:%d:%d\n",disk,j);
}

static VALUE encode(VALUE class, VALUE rb_data, VALUE rb_parity) {
  int dataBlocksSize = RARRAY_LEN(rb_data);
  int parityBlocksSize = RARRAY_LEN(rb_parity);
  VALUE *dataBlocks = RARRAY_PTR(rb_data);
  VALUE *dataBlock[dataBlocksSize];
  VALUE *parityBlocks = RARRAY_PTR(rb_parity);
  VALUE *parityBlock[parityBlocksSize];
  FILE *dataFH[dataBlocksSize];
  FILE *parityFH[parityBlocksSize];
  long dataLength[dataBlocksSize];
  long parityLength[parityBlocksSize];
  char **dataBuf;
  char **parBuf;
  int i;
  int j;
  int w = 8;
  int eof = 0;
  int **dumb;
  int *bitmatrix;
  int read = 0;
  int maxLength = 0;
  

  
  printf("Translate Ruby Elements to C Elements\n");
  //Translate Ruby Elements to C elements
  for (i = 0; i < dataBlocksSize; i++) {
    dataBlock[i] = RARRAY_PTR(*dataBlocks);
    dataFH[i] = fopen(RSTRING_PTR(*dataBlock[i]),"rb");
    if(dataFH[i] == NULL){
      printf("File %s doesn't exist or is unreadable. Exiting.",RSTRING_PTR(*dataBlock[i]));
      exit(1);
    }
    *dataBlock[i]++;
    dataLength[i] = NUM2INT(*dataBlock[i]);
    *dataBlock[i]++;
    fseek(dataFH[i],NUM2INT(*dataBlock[i]),SEEK_SET);
    *dataBlocks++;
  }
  
  for (i = 0; i < parityBlocksSize; i++) {
    parityBlock[i] = RARRAY_PTR(*parityBlocks);
    parityFH[i] = fopen(RSTRING_PTR(*parityBlock[i]),"wb");
    if(parityFH[i] == NULL){
      printf("Unable to write to %s file. Exiting.", RSTRING_PTR(*parityBlock[i]));
      exit(1);
    }
    *parityBlock[i]++;
    parityLength[i] = NUM2INT(*parityBlock[i]);
    *parityBlocks++;
  }
  
  printf("Init Vars\n");

  for (i = 0; i < dataBlocksSize; i++) {
    if(maxLength < dataLength[i]){
      maxLength = dataLength[i];
      printf("MaxLength:%d\n",maxLength);
    }
  }
  
  printf("Int data and par buffers\n");
  //Init data and par buffers
  dataBuf = calloc(dataBlocksSize, sizeof(char *));
  for (i = 0; i < dataBlocksSize; i++) {
    dataBuf[i] = calloc(maxLength,sizeof(char));
  }
  parBuf = calloc(parityBlocksSize, sizeof(char *));
  for (i = 0; i < parityBlocksSize; i++) {
    parBuf[i] = calloc(parityLength[i],sizeof(char));
  }
  
  printf("Calculate BitMatrix\n");
  //Calculate BitMatrix
  //bitmatrix = liberation_coding_bitmatrix(dataBlocksSize,w);
  bitmatrix = liber8tion_coding_bitmatrix(dataBlocksSize);
  if (bitmatrix == NULL) {
    printf("couldn't make coding matrix");
    exit;
  }
  
  //schedule = jerasure_smart_bitmatrix_to_schedule(dataBlocksSize, parityBlocksSize, w, bitmatrix);
  
  dumb = jerasure_dumb_bitmatrix_to_schedule(dataBlocksSize, parityBlocksSize, w, bitmatrix);
  
  printf("Loop over blocks of data\n");

  
  printf("Read data into databuf\n");
  for (i = 0; i < dataBlocksSize; i++) {
    read = fread(dataBuf[i],sizeof(char),dataLength[i],dataFH[i]);
  }
  
  printf("Encode\n");
  //jerasure_schedule_encode(k, m, w, dumb, data, coding, w*sizeof(long), sizeof(long));
  //jerasure_schedule_decode_lazy(k, m, w, bitmatrix, erasures, data, coding, w*sizeof(long), sizeof(long), 1);
  jerasure_schedule_encode(dataBlocksSize, parityBlocksSize, w, dumb, dataBuf, parBuf, maxLength*sizeof(char), sizeof(char));
  
  printf("Write to parity\n");
  //write parbuf
  for (i = 0; i < parityBlocksSize; i++) {
    fwrite(parBuf[i],sizeof(char),parityLength[i],parityFH[i]);
  }
  
  printf("Close File handles\n");
  //Close File Handles
  for (i = 0; i < dataBlocksSize; i++) {
    fclose(dataFH[i]);
  }
  
  for (i = 0; i < parityBlocksSize; i++) {
    fclose(parityFH[i]);
  }
  
  printf("Free Memory\n");
  
  for (i = 0; i < dataBlocksSize; i++) {
    free(dataBuf[i]);
  }
  free(dataBuf);
  for (i = 0; i < parityBlocksSize; i++) {
    free(parBuf[i]);
  }
  free(parBuf);
  
  
  printf("Return\n");
  return Qnil;
}

static VALUE decode(VALUE class, VALUE rb_data, VALUE rb_parity, VALUE rb_erasures) {
  int dataBlocksSize = RARRAY_LEN(rb_data);
  int parityBlocksSize = RARRAY_LEN(rb_parity);
  VALUE *dataBlocks = RARRAY_PTR(rb_data);
  VALUE *dataBlock[dataBlocksSize];
  VALUE *parityBlocks = RARRAY_PTR(rb_parity);
  VALUE *parityBlock[parityBlocksSize];
  FILE *dataFH[dataBlocksSize];
  FILE *parityFH[parityBlocksSize];
  long dataLength[dataBlocksSize];
  long parityLength[parityBlocksSize];
  //long maxLength = 0;
  int maxLength = 0;
  int erasures[RARRAY_LEN(rb_erasures) + 1];
  VALUE *erasureArr = RARRAY_PTR(rb_erasures);
  char **dataBuf;
  char **parBuf;
  int i;
  int j;
  int w = 8;
  //int eof = 0;
  //int **dumb;
  int *bitmatrix;
  int read = 0;
  
  for(i=0;i<RARRAY_LEN(rb_erasures);i++){
    erasures[i] = NUM2INT(erasureArr[i]);
    printf("Erased:%d:%d\n",i,erasures[i]);
  }
  erasures[i] = -1;
  printf("Erased:%d:%d\n",i,erasures[i]);
  
  printf("Translate Ruby Elements to C Elements\n");
  //Translate Ruby Elements to C elements
  for (i = 0; i < dataBlocksSize; i++) {
    dataBlock[i] = RARRAY_PTR(*dataBlocks);
    //Null Check and Erasure Support
    
    printf("File:%s\n",RSTRING_PTR(*dataBlock[i]));
    if(erasedCheck(i,erasures)) {
      printf("Disk %d is an erased disk.\n",i);
      printf("Opening file as append to force create.\n");
      dataFH[i] = fopen(RSTRING_PTR(*dataBlock[i]),"ab");
      fclose(dataFH[i]);
      printf("Closed File\n");
      printf("Opening file as read/write.\n");
      dataFH[i] = fopen(RSTRING_PTR(*dataBlock[i]),"r+b");
      if(dataFH[i] == NULL){
        printf("Couldn't open %s for writing. Exiting\n",RSTRING_PTR(*dataBlock[i]));
        exit(1);
      }
    } else {
      printf("Normal Disk %d\n",i);
      dataFH[i] = fopen(RSTRING_PTR(*dataBlock[i]),"rb");
      if(dataFH[i] == NULL){
        printf("Couldn't open %s for reading. Exiting\n",RSTRING_PTR(*dataBlock[i]));
        exit(1);
      }
      printf("Opened\n");
    }
    *dataBlock[i]++;
    dataLength[i] = NUM2INT(*dataBlock[i]);
    *dataBlock[i]++;
    //Will fseek work on a file you're writing to?
    fseek(dataFH[i],NUM2INT(*dataBlock[i]),SEEK_SET);
    *dataBlocks++;
  }
  
  //erasedCheck(i+dataBlocksSize,erasures)
  for (i = 0; i < parityBlocksSize; i++) {
    parityBlock[i] = RARRAY_PTR(*parityBlocks);
    //parityFH[i] = fopen(RSTRING_PTR(*parityBlock[i]),"rb");
    //Null Check and Erasure Support
    if(erasedCheck(i+dataBlocksSize,erasures)) {
      printf("Parity %d is an erased disk.\n",i);
      parityFH[i] = fopen(RSTRING_PTR(*parityBlock[i]),"wb");
      if(parityFH[i] == NULL){
        printf("Couldn't open %s for writing. Exiting\n",RSTRING_PTR(*parityBlock[i]));
        exit(1);
      }
    } else {
      parityFH[i] = fopen(RSTRING_PTR(*parityBlock[i]),"rb");
      if(parityFH[i] == NULL){
        printf("Couldn't open %s for reading. Exiting\n",RSTRING_PTR(*parityBlock[i]));
        exit(1);
      }
    }
    *parityBlock[i]++;
    parityLength[i] = NUM2INT(*parityBlock[i]);
    *parityBlocks++;
  }
  
  for (i = 0; i < dataBlocksSize; i++) {
    if(maxLength < dataLength[i]){
      maxLength = dataLength[i];
      printf("MaxLength:%d\n",maxLength);
    }
  }
  



  printf("Init Vars\n");
  
  printf("Int data and par buffers\n");
  //Init data and par buffers
  dataBuf = calloc(dataBlocksSize, sizeof(char *));
  for (i = 0; i < dataBlocksSize; i++) {
    dataBuf[i] = calloc(maxLength,sizeof(char));
  }
  parBuf = calloc(parityBlocksSize, sizeof(char *));
  for (i = 0; i < parityBlocksSize; i++) {
    parBuf[i] = calloc(parityLength[i],sizeof(char));
  }
  
  printf("Calculate BitMatrix\n");
  //Calculate BitMatrix
  //bitmatrix = liberation_coding_bitmatrix(dataBlocksSize,w);
  bitmatrix = liber8tion_coding_bitmatrix(dataBlocksSize);
  if (bitmatrix == NULL) {
    printf("couldn't make coding matrix");
    exit;
  }
  
  printf("Loop over blocks of data\n");

  
  printf("Read data into databuf\n");
  for (i = 0; i < dataBlocksSize; i++) {
    //Check if file has been erased
    if(!erasedCheck(i,erasures)) {
      read = fread(dataBuf[i],sizeof(char),dataLength[i],dataFH[i]);
    } else {
      //Shouldn't be necessary
      bzero(dataBuf[i],sizeof(char)*dataLength[i]);
    }
    //printf("SampleRead:%d:%d\n",i,dataBuf[i][0]);
    //outputData(i,dataBuf[i],dataLength[i]);

  }
  
  printf("Read data into parbuf\n");
  for (i = 0; i < parityBlocksSize; i++) {
    //Check if par has been erased
    if(!erasedCheck(i+dataBlocksSize,erasures)) {
      read = fread(parBuf[i],sizeof(char),parityLength[i],parityFH[i]);
    }
    //printf("SampleRead:%d:%d\n",i,parBuf[i][0]);
    //outputData(i+dataBlocksSize,parBuf[i],parityLength[i]);
  }
  
  printf("Decode\n");
  //jerasure_schedule_encode(k, m, w, dumb, data, coding, w*sizeof(long), sizeof(long));
  //jerasure_schedule_decode_lazy(k, m, w, bitmatrix, erasures, data, coding, w*sizeof(long), sizeof(long), 1);
  //jerasure_schedule_encode(dataBlocksSize, parityBlocksSize, w, dumb, dataBuf, parBuf, dataLength[0]*sizeof(char), sizeof(char));
  i = jerasure_schedule_decode_lazy(dataBlocksSize, parityBlocksSize, w, bitmatrix, erasures, dataBuf, parBuf, maxLength*sizeof(char), sizeof(char), 0);
  
  printf("Decode was successful? (-1 == bad):%d\n",i);
  
  /*
  printf("Write to parity\n");
  //write parbuf
  for (i = 0; i < parityBlocksSize; i++) {
    fwrite(parBuf[i],sizeof(char),parityLength[i],parityFH[i]);
  }
  */
  
  /*
  printf("Writing to file 1 \n");
  FILE *foo = fopen("data_1.out","wb");
  fwrite(dataBuf[2],sizeof(char),dataLength[2],foo);
  fclose(foo);

  printf("Writing to file 2\n");
  FILE *foo2 = fopen("data_2.out","wb");
  fwrite(dataBuf[1],sizeof(char),dataLength[1],foo2);
  fclose(foo2);*/
  
  printf("Write to Erased Files\n");
  for (i = 0; i < dataBlocksSize; i++) {
    //outputData(i,dataBuf[i],dataLength[i]);
    if(erasedCheck(i,erasures)) {

      fwrite(dataBuf[i],sizeof(char),dataLength[i],dataFH[i]);
    }
  }
  
  for (i = 0; i < parityBlocksSize; i++) {
    //outputData(i+dataBlocksSize,parBuf[i],parityLength[i]);
    if(erasedCheck(i+dataBlocksSize,erasures)) {
      fwrite(parBuf[i],sizeof(char),parityLength[i],parityFH[i]);
    }
  }
  
  
  printf("Close File handles\n");
  //Close File Handles
  for (i = 0; i < dataBlocksSize; i++) {
    fclose(dataFH[i]);
  }
  
  for (i = 0; i < parityBlocksSize; i++) {
    fclose(parityFH[i]);
  }

  printf("Free Memory\n");
  
  for (i = 0; i < dataBlocksSize; i++) {
    free(dataBuf[i]);
  }
  free(dataBuf);
  for (i = 0; i < parityBlocksSize; i++) {
    free(parBuf[i]);
  }
  free(parBuf);
  
  printf("Return\n");
  return Qnil;
}


void Init_parity_calc() {
  rb_mParity = rb_define_module("Parity");

  rb_cClass = rb_define_class_under(rb_mParity, "Class", rb_cObject);
  
  rb_define_method(rb_cClass, "encode", encode, 2);
  rb_define_method(rb_cClass, "decode", decode, 3);
}





