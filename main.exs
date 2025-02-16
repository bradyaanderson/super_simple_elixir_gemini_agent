Mix.install([
  {:req, "~> 0.4"},
  {:jason, "~> 1.4"},
  {:dotenv_parser, "~> 2.0"}
])

defmodule GeminiChat do
  @gemini_api_url "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

  def start() do
    IO.puts("Welcome to Gemini Chat! (Type 'quit' to exit)")
    chat_loop([])
  end

  defp chat_loop(history) do
    user_input = IO.gets("\nYou: ") |> String.trim()

    if user_input == "quit" do
      IO.puts("Goodbye!")
    else
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
    api_key = System.get_env("GEMINI_API_KEY") || DotenvParser.load_file(".env")["GEMINI_API_KEY"]

    if api_key do
      # Append new user message at the end of history (chronological)
      updated_history = history ++ [%{role: "user", parts: [%{text: user_input}]}]

      url = "#{@gemini_api_url}?key=#{api_key}"

      # Send the conversation as "contents" in the same format as your original code
      case Req.post(url, json: %{"contents" => updated_history}) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          # Extract the model's text
          text_response =
            body["candidates"]
            |> List.first()
            |> Map.get("content", %{})
            |> Map.get("parts", [%{}])
            |> List.first()
            |> Map.get("text", "No response")

          # Append model response to the history
          final_history = updated_history ++ [%{role: "model", parts: [%{text: text_response}]}]
          {:ok, text_response, final_history}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, "API returned status #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    else
      {:error, "GEMINI_API_KEY not found"}
    end
  end
end

GeminiChat.start()
