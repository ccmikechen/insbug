defmodule Insbug do
  @ins_url "https://www.instructables.com"

  def find_all(category, sort, output) do
    find_all(category, sort, 0, output)
  end

  def find_all(category, sort, offset, output) do
    IO.puts("Find from #{offset}")
    projects = find_page(category, sort, offset, output)

    case projects do
      [] ->
        IO.puts("Done!")
        :ok

      _ ->
        find_all(category, sort, offset + 60, output)
    end
  end

  def find_page(category, sort, offset, output) do
    url = "#{@ins_url}/#{category}/projects/?sort=#{sort}&offset=#{offset}"
    projects = get_projects(url)

    projects
    |> Enum.each(fn path ->
      Task.async(__MODULE__, :check_license, [path, output])
    end)

    projects
  end

  def check_license(path, output) do
    try do
      license = get_project_license(path)
      print_result(path, license)

      if license in [:CC0, :CC_BY] do
        record_project(path, output)
      end
    rescue
      _ -> nil
    end
  end

  defp print_result(path, license) do
    case license do
      :CC0 ->
        IO.puts("#{IO.ANSI.green()}#{license} - #{path}")

      :CC_BY ->
        IO.puts("#{IO.ANSI.white()}#{license} - #{path}")

      _ ->
        IO.puts("#{IO.ANSI.red()}#{license} - #{path}")
    end
  end

  defp record_project(path, output) do
    with :ok <- File.mkdir_p(Path.dirname(output)) do
      File.write(output, "#{path}\n", [:append])
    end
  end

  defp get_projects(url) do
    case HTTPoison.get(url) do
      {:ok, %{body: body}} ->
        body
        |> Floki.find(".category-projects-ible a")
        |> Floki.attribute("href")
        |> Enum.filter(&project?/1)
        |> Enum.uniq()

      _ ->
        raise "Wrong URL or website is down"
    end
  end

  defp project?(path) do
    case path do
      "/id/" <> _ -> true
      _ -> false
    end
  end

  defp get_project_license(path) do
    case HTTPoison.get(@ins_url <> path) do
      {:ok, %{body: body}} ->
        license_url =
          body
          |> Floki.find(".license-btn")
          |> Floki.attribute("data-url")

        case license_url do
          [url | _] -> parse_license(url)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_license(url) do
    case url do
      "https://creativecommons.org/licenses/by-nc-sa/4.0/" ->
        :CC_BY_NC_SA

      "https://creativecommons.org/licenses/by/4.0/" ->
        :CC_BY

      "https://creativecommons.org/choose/zero/" ->
        :CC0

      _ ->
        nil
    end
  end
end
