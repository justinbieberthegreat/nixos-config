function timer --description 'Simple countdown timer'
    if test -z "$argv[1]"
        echo "Usage: timer <duration>"
        echo "Examples: timer 1h, timer 30m, timer 45s, timer 90"
        return 1
    end

    set input $argv[1]
    set secs 0

    if string match -q "*h" -- $input
        set secs (math (string trim -c h -- $input) "*" 3600)
    else if string match -q "*m" -- $input
        set secs (math (string trim -c m -- $input) "*" 60)
    else if string match -q "*s" -- $input
        set secs (string trim -c s -- $input)
    else if string match -r '^\d+$' -- $input
        set secs $input
    else
        echo "Invalid format. Use h, m, s, or just numbers (seconds)."
        return 1
    end

    echo "Started countdown for $input..."

    while test $secs -gt 0
        set hours (math "floor($secs / 3600)")
        set minutes (math "floor(($secs % 3600) / 60)")
        set seconds (math "$secs % 60")

        printf "\r⏳ %02d:%02d:%02d " $hours $minutes $seconds
        sleep 1
        set secs (math $secs - 1)
    end

    printf "\r✅ Time's up!      \n\a"
end
