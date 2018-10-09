#include <aws/core/Aws.h>
#include <aws/core/utils/Outcome.h>
#include <aws/polly/PollyClient.h>
#include <aws/polly/model/DescribeVoicesRequest.h>
#include <aws/polly/model/DescribeVoicesResult.h>

int main(int argc, char** argv)
{
    Aws::SDKOptions options;
    Aws::InitAPI(options);
    {
        Aws::Polly::PollyClient pollyClient;
        Aws::Polly::Model::DescribeVoicesRequest describeVoicesRequest;

        const auto & name = pollyClient.GetServiceClientName();
        std::cout << "I am " << name << std::endl;

        const Aws::Polly::Model::DescribeVoicesOutcome outcome = pollyClient.DescribeVoices(describeVoicesRequest);
        if (outcome.IsSuccess()) {
            auto const & result = outcome.GetResult();

            for (const auto & voice : result.GetVoices()) {
                std::cout << Aws::Polly::Model::VoiceIdMapper::GetNameForVoiceId(voice.GetId()) << std::endl;
            }
        } else {
            std::cout << "no voice returned " << std::endl;
        }
    }
    Aws::ShutdownAPI(options);
    return 0;
}
