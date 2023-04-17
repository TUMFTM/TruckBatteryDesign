module Downsampler
using DataFrames, DelimitedFiles
export downsample_and_save

function downsample_and_save(t, data, nbins, filename)
    #Save downsampled data to .csv for transient plot
    Ibins = Int.(round.(LinRange(1,length(data),nbins+1)))
    minmax_vals = []
    minmax_ts = []
    for (I1,I2) in zip(Ibins[1:end-1],Ibins[2:end])
        data_chunk = data[I1:I2]
        time_chunk = t[I1:I2]
        valmax, Imax = findmax(data_chunk)
        valmin, Imin = findmin(data_chunk)
        tmax = time_chunk[Imax]
        tmin = time_chunk[Imin]
        append!(minmax_vals, [valmax, valmin])
        append!(minmax_ts, [tmax, tmin])
    end
    
    #Sort unique values
    df = sort(unique(DataFrame(t=minmax_ts, val = minmax_vals)))

    open("$(filename).txt", "w") do io
        writedlm(io, [df.t df.val], ' ')
    end

    return nothing
end
end