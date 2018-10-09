#include <aws/core/Aws.h>

int main(int argc, char** argv)
{
    Aws::SDKOptions options;
    Aws::InitAPI(options);
    {
        // make your SDK calls here.
        std::cout << "hello polly" << std::endl;
    }
    Aws::ShutdownAPI(options);
    return 0;
}
