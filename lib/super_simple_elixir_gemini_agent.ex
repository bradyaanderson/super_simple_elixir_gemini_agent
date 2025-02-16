defmodule SuperSimpleElixirGeminiAgent do
  @moduledoc """
  A simple chat interface using the Gemini model that retains chat history.
  """

  use Application

  @gemini_api_url "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

  def start(_type, _args) do
    IO.puts("Welcome to Gemini Chat! (Type 'quit' to exit)")
    chat_loop([])
    {:ok, self()}
  end

  defp chat_loop(history) do
    user_input = IO.gets("\nYou: ") |> String.trim()

    case user_input do
      "quit" ->
        IO.puts("Goodbye!")

      _ ->
        case get_response(user_input, history) do
          {:ok, response, updated_history} ->
            IO.puts("\nGemini: #{response}")
            chat_loop(updated_history)

          {:error, reason} ->
            IO.puts("Error: #{reason}")
            chat_loop(history)
        end
    end
  end

  defp get_response(user_input, history) do
    api_key = fetch_api_key()

    case api_key do
      nil ->
        {:error, "GEMINI_API_KEY not found"}

      _ ->
        updated_history = append_user(history, user_input)
        url = "#{@gemini_api_url}?key=#{api_key}"

        case Req.post(url, json: %{"contents" => updated_history}) do
          {:ok, %Req.Response{status: 200, body: body}} ->
            text_response = extract_text(body)
            final_history = append_model(updated_history, text_response)
            {:ok, text_response, final_history}

          {:ok, %Req.Response{status: status, body: body}} ->
            {:error, "API returned status #{status}: #{inspect(body)}"}

          {:error, reason} ->
            {:error, "Request failed: #{inspect(reason)}"}
        end
    end
  end

  defp fetch_api_key do
    if System.get_env("GEMINI_API_KEY") do
      System.get_env("GEMINI_API_KEY")
    else
      DotenvParser.parse_file(".env")
      |> Enum.into(%{})
      |> Map.get("GEMINI_API_KEY")
    end
  end

  defp append_user(history, user_text) do
    history ++ [%{role: "user", parts: [%{text: user_text}]}]
  end

  defp append_model(history, model_text) do
    history ++ [%{role: "model", parts: [%{text: model_text}]}]
  end

  defp extract_text(body) do
    body["candidates"]
    |> List.first()
    |> Map.get("content", %{})
    |> Map.get("parts", [%{}])
    |> List.first()
    |> Map.get("text", "No response")
  end
end
