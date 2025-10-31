"""Test for planning agent functionality."""
import pytest
from unittest.mock import patch, MagicMock
from src.planning_agent import planner_agent


def test_planner_agent_import():
    """Test that planner_agent can be imported successfully."""
    # If we get here without import errors, the test passes
    assert planner_agent is not None


def test_planner_agent_with_valid_api_key():
    """Test planner_agent with a simple prompt (requires valid API key)."""
    # This test will only pass if OPENAI_API_KEY is properly configured
    try:
        result = planner_agent("Write a short summary about Python programming")
        assert isinstance(result, list)
        assert len(result) > 0
        # Each item should be a string (step description)
        for step in result:
            assert isinstance(step, str)
            assert len(step.strip()) > 0
    except Exception as e:
        # If API key issues, skip the test with informative message
        if "401" in str(e) or "invalid_api_key" in str(e):
            pytest.skip("Test requires valid OPENAI_API_KEY")
        elif "429" in str(e) or "quota" in str(e):
            pytest.skip("Test skipped due to API quota limits")
        else:
            # Re-raise other unexpected errors
            raise


@patch('src.planning_agent.client')
def test_planner_agent_mocked(mock_client):
    """Test planner_agent with mocked OpenAI client."""
    # Mock the response
    mock_response = MagicMock()
    mock_response.choices = [MagicMock()]
    mock_response.choices[0].message.content = '''
    [
        "Research Python basics",
        "Write introduction section",
        "Create code examples"
    ]
    '''
    mock_client.chat.completions.create.return_value = mock_response

    result = planner_agent("Write a short summary about Python programming")

    # Verify the client was called
    mock_client.chat.completions.create.assert_called_once()

    # Verify the result format
    assert isinstance(result, list)
    assert len(result) >= 3  # The function enforces minimum required steps

    # Check that required steps are present (the function enforces these)
    required_steps = [
        "Research agent: Use Tavily to perform a broad web search",
        "Research agent: For each collected item, search on arXiv",
        "Writer agent: Generate the final comprehensive Markdown report"
    ]

    for required in required_steps:
        assert any(required in step for step in result), f"Required step pattern '{required}' not found in result"
