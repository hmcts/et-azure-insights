RSpec.configure do |c|
  c.around do |example|
    last_span = ::EtAzureInsights::Correlation::Span.current
    #EtAzureInsights::Correlation::Span::reset_current
    expect(last_span.root?).to be(true), "Spans were left open - #{last_span.path}"
    example.run
  end
end