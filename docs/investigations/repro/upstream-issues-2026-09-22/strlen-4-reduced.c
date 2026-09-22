extern int printf (const char*, ...);
extern __SIZE_TYPE__ strlen (const char*);
typedef char A28[28];
typedef A28 A3_28[3];
typedef A3_28 A2_3_28[2];
static const A2_3_28 a = {
};
volatile int v0 = 0;
volatile int v1 = 1;
volatile int v2 = 2;
#define A(expr, N)							\
  ((strlen (expr) == N)							\
   ? (void)0 : (printf ("line %i: strlen (%s = \"%s\") != %i\n",	\
			__LINE__, #expr, expr, N),			\
		__builtin_abort ()))
/* Verify that strlen() involving pointer to array arguments computes
   the correct result.  */
void test_array_ptr (void)
{
  int i0 = 0;
  int i1 = i0 + 1;
  int i2 = i1 + 1;
  A (*(&a[0][0] + i0), 1);
  A (*(&a[0][0] + i1), 3);
  A (*(&a[0][0] + i2), 5);
  A (*(&a[0][1] - i1), 1);
  A (*(&a[i0][i0] + i0), 1);
  A (*(&a[i0][i0] + i1), 3);
  A (*(&a[i0][i0] + i2), 5);
  A (*(&a[i0][i1] - i1), 1);
  A (*(&a[i0][i1] + i0), 3);
  A (*(&a[i0][i1] + i1), 5);
  A (*(&a[i0][i2] - i2), 1);
  A (*(&a[i0][i2] - i1), 3);
  A (*(&a[i0][i2] + i0), 5);
  A (*(&a[i1][i0] + i0), 7);
  A (*(&a[i1][i0] + i1), 9);
  A (*(&a[i1][i0] + i2), 11);
  A (*(&a[i1][i1] - i1), 7);
  A (*(&a[i1][i1] + i0), 9);
  A (*(&a[i1][i1] + i1), 11);
  A (*(&a[i1][i2] - i2), 7);
  A (*(&a[i1][i2] - i1), 9);
  A (*(&a[i1][i2] - i0), 11);
  A (*(&a[i0][i0] + v0), 1);
  A (*(&a[i0][i0] + v1), 3);
  A (*(&a[i0][i0] + v2), 5);
  A (*(&a[i0][i1] - v1), 1);
  A (*(&a[i0][i1] + v0), 3);
  A (*(&a[i0][i1] + v1), 5);
  A (*(&a[i0][i2] - v2), 1);
  A (*(&a[i0][i2] - v1), 3);
  A (*(&a[i0][i2] + v0), 5);
  A (*(&a[i1][i0] + v0), 7);
  A (*(&a[i1][i0] + v1), 9);
  A (*(&a[i1][i0] + v2), 11);
}
/* Verify that strlen() involving pointers and arrays of pointers
   to array arguments computes the correct result.  */
void test_ptr_array (void)
{
}
int main (void)
{
}
