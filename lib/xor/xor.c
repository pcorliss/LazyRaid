#include <ruby.h>
#include <stdio.h>
#include <stdlib.h>

static VALUE rb_mXor;

static VALUE xor_multi(VALUE class, VALUE rb_blocks, VALUE outfile, VALUE buffer) {
  
  unsigned int numBlocks = RARRAY_LEN(rb_blocks);
  unsigned long i;
  unsigned long j;
  VALUE *element = RARRAY_PTR(rb_blocks);
  VALUE *subelem[numBlocks];
  FILE *infile;
  FILE *outFile;
  unsigned long length = 0;
  unsigned long offset = 0;
  unsigned long outbufsize = NUM2INT(buffer);
  //Need to be dynamically allocated
  //unsigned char outbuf[outbufsize];
  //unsigned char filebuf[outbufsize];
  unsigned char *outbuf = calloc(outbufsize,sizeof(*outbuf));
  unsigned char *filebuf = calloc(outbufsize,sizeof(*filebuf));
  
  if(outbuf == NULL || filebuf == NULL){
    //printf("Unable to allocate memory:%d:%d:%d",outbufsize,outbufsize * sizeof(unsigned char),sizeof(unsigned char));
    printf("Unable to allocate memory");
    exit;
  }
  
  for(i=0;i<numBlocks;i++){
    subelem[i] = RARRAY_PTR(*element);
    infile = fopen(RSTRING_PTR(*subelem[i]),"rb");
    *subelem[i]++;
    length = NUM2INT(*subelem[i]);
    *subelem[i]++;
    offset = NUM2INT(*subelem[i]);
    fseek(infile,offset,SEEK_SET);
    //printf("%d:File Opened:%d:%d\n",i,length,offset);
    
    if(i == 0){
      //Init the outbuffer on the first run
      fread(outbuf, length, 1, infile);
      //Shouldn't be needed given that we're using calloc
      /*for(j=length;j<outbufsize;j++){
        outbuf[j] = 0;
      }*/
    } else {
      fread(filebuf, length, 1, infile);
      for(j=0;j<length;j++){
        outbuf[j] ^= filebuf[j];
      }
    }
    fclose(infile);
    element++;
  }
  free(filebuf);
  
  FILE *fileout = fopen(RSTRING_PTR(outfile),"ab");
  fwrite(outbuf, sizeof(*outbuf), outbufsize, fileout);
  fclose(fileout);
  
  free(outbuf);
  
  return Qnil;
}

void Init_xor() {
  rb_mXor = rb_define_module("XOR");

  rb_cClass = rb_define_class_under(rb_mXor, "Class", rb_cObject);
  
  rb_define_method(rb_cClass, "xor_multi", xor_multi, 3);
}
